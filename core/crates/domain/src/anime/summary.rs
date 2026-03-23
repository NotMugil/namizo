use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnimeSummary {
    pub id: u32,
    pub title: String,
    pub description: Option<String>,
    pub cover_image: String,
    pub average_score: Option<u8>,
    pub genres: Vec<String>,
    pub format: Option<String>,
    pub episodes: Option<u32>,
    pub banner_image: Option<String>,
    pub trailer_id: Option<String>,
    pub status: Option<String>,
    pub next_airing_episode: Option<u32>,
    pub next_airing_at: Option<i64>,
}