use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StreamableAnime {
    pub id: String,
    pub title: String,
    pub available_episodes: Option<i32>,
    pub season: Option<String>,
    pub year: Option<i32>,
    pub media_type: Option<String>,
    pub status: Option<String>,
}