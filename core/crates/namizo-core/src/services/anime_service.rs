use std::collections::HashMap;
use std::sync::Arc;
use futures::future::join_all;
use anilist::queries::{by_genre, details, popular, top_rated, trending};
use anilist::AnilistClient;
use domain::anime::{AnimeDetails, AnimeSummary};

pub struct AnimeService {
    client: Arc<AnilistClient>,
}

impl AnimeService {
    pub fn new() -> Self {
        Self {
            client: Arc::new(AnilistClient::new()),
        }
    }

    pub async fn trending(&self, per_page: u8) -> Result<Vec<AnimeSummary>, String> {
        trending::fetch_trending(&self.client, per_page)
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn popular(&self, per_page: u8) -> Result<Vec<AnimeSummary>, String> {
        popular::fetch_popular(&self.client, per_page)
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn top_rated(&self, per_page: u8) -> Result<Vec<AnimeSummary>, String> {
        top_rated::fetch_top_rated(&self.client, per_page)
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn genres_batch(
        &self,
        genres: Vec<String>,
    ) -> Result<HashMap<String, Vec<AnimeSummary>>, String> {
        let futures: Vec<_> = genres
            .into_iter()
            .map(|genre| {
                let client = Arc::clone(&self.client);
                async move {
                    let results = by_genre::fetch_by_genre(&client, &genre, 20)
                        .await
                        .map_err(|e| e.to_string())?;
                    Ok::<(String, Vec<AnimeSummary>), String>((genre, results))
                }
            })
            .collect();

        join_all(futures)
            .await
            .into_iter()
            .collect::<Result<HashMap<_, _>, _>>()
    }

    pub async fn details(&self, id: u32) -> Result<AnimeDetails, String> {
        details::fetch_details(&self.client, id)
            .await
            .map_err(|e| e.to_string())
    }
}