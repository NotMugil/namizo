use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ShelfState {
    Watching,
    Planning,
    Completed,
    Rewatching,
    Dropped,
    Paused,
}

impl ShelfState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Watching => "WATCHING",
            Self::Planning => "PLANNING",
            Self::Completed => "COMPLETED",
            Self::Rewatching => "REWATCHING",
            Self::Dropped => "DROPPED",
            Self::Paused => "PAUSED",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "WATCHING" => Some(Self::Watching),
            "PLANNING" => Some(Self::Planning),
            "COMPLETED" => Some(Self::Completed),
            "REWATCHING" => Some(Self::Rewatching),
            "DROPPED" => Some(Self::Dropped),
            "PAUSED" => Some(Self::Paused),
            _ => None,
        }
    }
}

impl Default for ShelfState {
    fn default() -> Self {
        Self::Planning
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ShelfEntry {
    pub anilist_id: u32,
    pub title: String,
    pub cover_image: Option<String>,
    pub banner_image: Option<String>,
    pub format: Option<String>,
    pub episode_total: Option<u32>,
    pub score: Option<u8>,
    #[serde(default)]
    pub genres: Vec<String>,
    pub anilist_status: Option<String>,
    pub season: Option<String>,
    pub season_year: Option<u32>,
    pub popularity: Option<u32>,
    pub average_score: Option<u8>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    #[serde(default)]
    pub rewatches: u32,
    pub notes: Option<String>,
    pub status: ShelfState,
    pub progress: u32,
    pub progress_percent: u8,
    pub last_episode: Option<u32>,
    pub last_watched_at: Option<i64>,
    pub created_at: i64,
    pub updated_at: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EpisodeState {
    pub anilist_id: u32,
    pub episode: u32,
    pub percent: u8,
    pub watched_at: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WatchEvent {
    pub id: Option<i64>,
    pub anilist_id: u32,
    pub episode: u32,
    pub percent: u8,
    pub watched_at: i64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum SyncKind {
    Update,
    Progress,
    Remove,
}

impl SyncKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Update => "UPDATE",
            Self::Progress => "PROGRESS",
            Self::Remove => "REMOVE",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "UPDATE" => Some(Self::Update),
            "PROGRESS" => Some(Self::Progress),
            "REMOVE" => Some(Self::Remove),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SyncJob {
    pub id: Option<i64>,
    pub anilist_id: u32,
    pub kind: SyncKind,
    pub payload: String,
    pub attempts: u32,
    pub created_at: i64,
    pub sent_at: Option<i64>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LibraryFacets {
    #[serde(default)]
    pub genres: Vec<String>,
    #[serde(default)]
    pub release_statuses: Vec<String>,
    #[serde(default)]
    pub seasons: Vec<String>,
    #[serde(default)]
    pub years: Vec<u32>,
}

#[cfg(test)]
mod tests {
    use super::ShelfState;

    #[test]
    fn shelf_state_round_trip_includes_rewatching() {
        assert_eq!(
            ShelfState::parse("REWATCHING"),
            Some(ShelfState::Rewatching)
        );
        assert_eq!(ShelfState::Rewatching.as_str(), "REWATCHING");
    }
}