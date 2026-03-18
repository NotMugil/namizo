use serde::{Deserialize, Serialize};
use crate::anime::summary::AnimeSummary;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnimeDetails {
    pub id: u32,
    pub title: String,
    pub title_japanese: Option<String>,
    pub cover_image: String,
    pub banner_image: Option<String>,
    pub description: Option<String>,
    pub genres: Vec<String>,
    pub average_score: Option<u8>,
    pub status: Option<String>,      // "RELEASING", "FINISHED", "NOT_YET_RELEASED"
    pub season: Option<String>,      // "SPRING", "SUMMER", "FALL", "WINTER"
    pub season_year: Option<u32>,
    pub format: Option<String>,      // "TV", "MOVIE", "OVA", "ONA"
    pub episode_count: Option<u32>,
    pub studios: Vec<String>,
    pub trailer_id: Option<String>,  // YouTube video ID only, site filtered in mapping
    pub characters: Vec<Character>,
    pub relations: Vec<AnimeSummary>,
    pub recommendations: Vec<AnimeSummary>,
    pub episodes: Vec<Episode>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Character {
    pub id: u32,
    pub name: String,
    pub image: Option<String>,
    pub role: String,        // "MAIN", "SUPPORTING"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Episode {
    pub number: u32,
    pub title: Option<String>,
    pub thumbnail: Option<String>,
    pub description: Option<String>,
}