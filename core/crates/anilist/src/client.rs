use reqwest::Client;
use serde_json::{json, Value};
use domain::{AnimeDetails, AnimeSummary};
use crate::{error::AnilistError, graphql, mapping};

const ANILIST_URL: &str = "https://graphql.anilist.co";

pub struct AnilistClient {
    client: Client,
}

impl AnilistClient {
    pub fn new() -> Self {
        Self { client: Client::new() }
    }

    pub async fn fetch_media_page(&self, variables: Value) -> Result<Vec<AnimeSummary>, AnilistError> {
        let response = self.post(graphql::MEDIA_PAGE_QUERY, variables).await?;
        mapping::to_summary_list(&response)
    }

    pub async fn fetch_details(&self, id: u32) -> Result<AnimeDetails, AnilistError> {
        let response = self.post(graphql::DETAILS_QUERY, json!({ "id": id })).await?;
        mapping::to_details(&response)
    }

    // ── private ──────────────────────────────────────────────────────────────

    async fn post(&self, query: &str, variables: Value) -> Result<Value, AnilistError> {
        self.client
            .post(ANILIST_URL)
            .json(&json!({ "query": query, "variables": variables }))
            .send()
            .await?
            .json()
            .await
            .map_err(AnilistError::Http)
    }
}