use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JikanEpisode {
    pub number: u32,
    pub mal_id: u32,
    pub title: Option<String>,
    pub filler: bool,
    pub recap: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JikanEpisodesPage {
    pub page: u32,
    pub has_next_page: bool,
    pub total_episodes: Option<u32>,
    pub episodes: Vec<JikanEpisode>,
}