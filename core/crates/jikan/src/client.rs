use crate::{JikanEpisode, JikanEpisodesPage, JikanError};
use reqwest::Client;
use serde_json::Value;

const JIKAN_URL: &str = "https://api.jikan.moe/v4";

pub struct JikanClient {
    client: Client,
}

impl JikanClient {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
        }
    }

    pub async fn get_episodes_page(&self, mal_id: u32, page: u32) -> Result<JikanEpisodesPage, JikanError> {
        let page = page.max(1);
        let url = format!("{}/anime/{}/episodes?page={}", JIKAN_URL, mal_id, page);
        let response: Value = self.client.get(&url).send().await?.json().await?;

        let data = response["data"]
            .as_array()
            .ok_or_else(|| JikanError::Parse("missing data array".into()))?;

        let episodes = data
            .iter()
            .filter_map(|episode| {
                let Some(mal_episode_id) = episode["mal_id"].as_u64() else {
                    return None;
                };

                Some(JikanEpisode {
                    number: mal_episode_id as u32,
                    mal_id: mal_episode_id as u32,
                    title: episode["title"].as_str().map(|s| s.to_string()),
                    filler: episode["filler"].as_bool().unwrap_or(false),
                    recap: episode["recap"].as_bool().unwrap_or(false),
                })
            })
            .collect::<Vec<_>>();

        let has_next_page = response["pagination"]["has_next_page"]
            .as_bool()
            .unwrap_or(false);
        let total_episodes = response["pagination"]["items"]["total"]
            .as_u64()
            .map(|value| value as u32)
            .filter(|value| *value > 0);

        Ok(JikanEpisodesPage {
            page,
            has_next_page,
            total_episodes,
            episodes,
        })
    }

    pub async fn get_episodes(&self, mal_id: u32) -> Result<Vec<JikanEpisode>, JikanError> {
        let mut page = 1u32;
        let mut all_episodes = Vec::new();

        loop {
            let paged = self.get_episodes_page(mal_id, page).await?;
            if paged.episodes.is_empty() {
                break;
            }

            all_episodes.extend(paged.episodes);

            if !paged.has_next_page {
                break;
            }

            page += 1;
        }

        Ok(all_episodes)
    }
}