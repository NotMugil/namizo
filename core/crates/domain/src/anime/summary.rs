use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnimeSummary {
    pub id: u32,
    pub title: String,
    pub cover_image: String,
    pub average_score: Option<u8>,
    pub genres: Vec<String>,
    pub format: Option<String>,
    pub episodes: Option<u32>,
}