use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JikanEpisode {
    pub mal_id: u32,
    pub title: Option<String>,
    pub filler: bool,
    pub recap: bool,
}