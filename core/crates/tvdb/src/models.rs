use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TvdbEpisode {
    pub number: u32,
    pub title: Option<String>,
    pub thumbnail: Option<String>,
}