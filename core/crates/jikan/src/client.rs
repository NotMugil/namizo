use reqwest::Client;
use serde_json::Value;
use crate::{JikanError, JikanEpisode};

const JIKAN_URL: &str = "https://api.jikan.moe/v4";

pub struct JikanClient {
    client: Client,
}

impl JikanClient {
    pub fn new() -> Self {
        Self { client: Client::new() }
    }

    pub async fn get_episodes(&self, mal_id: u32) -> Result<Vec<JikanEpisode>, JikanError> {
        let url = format!("{}/anime/{}/episodes", JIKAN_URL, mal_id);
        let response: Value = self.client
            .get(&url)
            .send()
            .await?
            .json()
            .await?;

        let episodes = response["data"]
            .as_array()
            .ok_or_else(|| JikanError::Parse("missing data array".into()))?
            .iter()
            .filter_map(|ep| {
                Some(JikanEpisode {
                    mal_id: ep["mal_id"].as_u64()? as u32,
                    title:  ep["title"].as_str().map(|s| s.to_string()),
                    filler: ep["filler"].as_bool().unwrap_or(false),
                    recap:  ep["recap"].as_bool().unwrap_or(false),
                })
            })
            .collect();

        Ok(episodes)
    }
}