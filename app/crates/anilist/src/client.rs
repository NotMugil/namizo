use std::time::Duration;
use reqwest::Client;
use serde_json::{json, Value};
use domain::{AnimeDetails, AnimeSummary, DiscoverPage};
use crate::{error::AnilistError, graphql, mapping};

const ANILIST_URL: &str = "https://graphql.anilist.co";
const MAX_RETRIES: u32 = 3;
const DEFAULT_RETRY_AFTER_SECS: u64 = 60;

pub struct AnilistClient {
    client: Client,
}

impl AnilistClient {
    pub fn new() -> Self {
        Self { client: Client::new() }
    }

    pub async fn fetch_media_page(&self, variables: Value) -> Result<Vec<AnimeSummary>, AnilistError> {
        let response = self.request_with_retry(graphql::MEDIA_PAGE_QUERY, variables).await?;
        mapping::to_summary_list(&response)
    }

    pub async fn fetch_media_page_with_info(
        &self,
        variables: Value,
    ) -> Result<DiscoverPage, AnilistError> {
        let response = self.request_with_retry(graphql::MEDIA_PAGE_QUERY, variables).await?;
        mapping::to_discover_page(&response)
    }

    pub async fn fetch_details(&self, id: u32) -> Result<AnimeDetails, AnilistError> {
        let response = self.request_with_retry(graphql::DETAILS_QUERY, json!({ "id": id })).await?;
        mapping::to_details(&response)
    }

    pub async fn fetch_genres(&self) -> Result<Vec<String>, AnilistError> {
        let response = self
            .request_with_retry(graphql::FACETS_QUERY, json!({ "page": 1, "perPage": 50 }))
            .await?;
        if let Some(errors) = response["errors"].as_array() {
            if !errors.is_empty() {
                let messages = errors
                    .iter()
                    .filter_map(|entry| entry["message"].as_str())
                    .map(str::trim)
                    .filter(|message| !message.is_empty())
                    .collect::<Vec<_>>();
                let message = if messages.is_empty() {
                    "AniList GraphQL request failed.".to_string()
                } else {
                    messages.join(" | ")
                };
                return Err(AnilistError::Parse(message));
            }
        }

        let media_items = response["data"]["Page"]["media"]
            .as_array()
            .ok_or_else(|| AnilistError::Parse("missing facets media array".to_string()))?;

        let genres = media_items
            .iter()
            .flat_map(|media| media["genres"].as_array().into_iter().flatten())
            .filter_map(|value| value.as_str())
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned)
            .collect::<Vec<_>>();

        Ok(genres)
    }

    // ── private ──────────────────────────────────────────────────────────────

    /// Makes a GraphQL request, retrying up to MAX_RETRIES times on 429.
    async fn request_with_retry(&self, query: &str, variables: Value) -> Result<Value, AnilistError> {
        for attempt in 0..MAX_RETRIES {
            match self.post(query, variables.clone()).await {
                Ok(v) => return Ok(v),
                Err(AnilistError::RateLimit(wait)) => {
                    if attempt + 1 >= MAX_RETRIES {
                        return Err(AnilistError::RateLimit(wait));
                    }
                    // Cap the wait at 60s and apply exponential backoff on top
                    let backoff = wait.min(DEFAULT_RETRY_AFTER_SECS) * (1 << attempt);
                    tokio::time::sleep(Duration::from_secs(backoff)).await;
                }
                Err(e) => return Err(e),
            }
        }
        unreachable!()
    }

    /// Raw HTTP POST — returns `RateLimit` error on 429 before attempting JSON parse.
    async fn post(&self, query: &str, variables: Value) -> Result<Value, AnilistError> {
        let response = self.client
            .post(ANILIST_URL)
            .json(&json!({ "query": query, "variables": variables }))
            .send()
            .await?;

        if response.status() == reqwest::StatusCode::TOO_MANY_REQUESTS {
            let retry_after = response
                .headers()
                .get("retry-after")
                .and_then(|v| v.to_str().ok())
                .and_then(|s| s.parse::<u64>().ok())
                .unwrap_or(DEFAULT_RETRY_AFTER_SECS);
            return Err(AnilistError::RateLimit(retry_after));
        }

        response.json().await.map_err(AnilistError::Http)
    }
}
