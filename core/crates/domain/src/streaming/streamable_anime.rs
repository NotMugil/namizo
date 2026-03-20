use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StreamableAnime {
    pub id: String,
    pub title: String,
    pub available_episodes: Option<i32>,
}