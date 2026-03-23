use serde::{Deserialize, Serialize};

use crate::anime::summary::AnimeSummary;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DiscoverFilters {
    pub search: Option<String>,
    #[serde(default)]
    pub genres: Vec<String>,
    #[serde(default)]
    pub formats: Vec<String>,
    pub status: Option<String>,
    pub season: Option<String>,
    pub season_year: Option<u32>,
    #[serde(default)]
    pub sort: Vec<String>,
    pub is_adult: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscoverPage {
    pub items: Vec<AnimeSummary>,
    pub current_page: u32,
    pub has_next_page: bool,
    pub total: Option<u32>,
    pub last_page: Option<u32>,
    pub per_page: Option<u32>,
}