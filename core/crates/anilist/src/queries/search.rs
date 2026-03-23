use crate::{AnilistClient, AnilistError};
use domain::AnimeSummary;
use serde_json::json;

pub async fn fetch_search(
    client: &AnilistClient,
    search: &str,
    per_page: u8,
) -> Result<Vec<AnimeSummary>, AnilistError> {
    client
        .fetch_media_page(json!({
            "sort": ["POPULARITY_DESC"],
            "search": search,
            "perPage": per_page,
            "page": 1,
        }))
        .await
}