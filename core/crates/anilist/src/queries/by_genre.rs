use serde_json::json;
use domain::anime::AnimeSummary;
use crate::{AnilistClient, AnilistError};

pub async fn fetch_by_genre(client: &AnilistClient, genre: &str, per_page: u8) -> Result<Vec<AnimeSummary>, AnilistError> {
    client.fetch_media_page(json!({
        "sort": ["POPULARITY_DESC"],
        "genre": genre,
        "perPage": per_page,
        "page": 1,
    })).await
}