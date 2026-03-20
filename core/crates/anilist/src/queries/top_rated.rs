use serde_json::json;
use domain::AnimeSummary;
use crate::{AnilistClient, AnilistError};

pub async fn fetch_top_rated(client: &AnilistClient, per_page: u8) -> Result<Vec<AnimeSummary>, AnilistError> {
    client.fetch_media_page(json!({
        "sort": ["SCORE_DESC"],
        "perPage": per_page,
        "page": 1,
    })).await
}