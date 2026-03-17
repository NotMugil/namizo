use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnimeDetails {
    pub id: u32,
    pub title: String,
    pub cover_image: String,
    pub banner_image: Option<String>,
    pub description: Option<String>,
    pub genres: Vec<String>,
    pub average_score: Option<u8>,
    pub status: Option<String>,      // "RELEASING", "FINISHED", "NOT_YET_RELEASED"
    pub season: Option<String>,      // "SPRING", "SUMMER", "FALL", "WINTER"
    pub season_year: Option<u32>,
    pub format: Option<String>,      // "TV", "MOVIE", "OVA", "ONA"
    pub episodes: Option<u32>,
    pub studios: Vec<String>,
    pub trailer_id: Option<String>,  // YouTube video ID only, site filtered in mapping
}