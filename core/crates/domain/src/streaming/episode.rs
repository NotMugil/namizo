use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StreamingEpisode {
    pub anime_id: String,
    pub number: String,
    pub source_id: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct EpisodeUpdate {
    pub anime_id: Option<String>,
    pub number: Option<String>,
    pub source_id: Option<String>,
}

impl StreamingEpisode {
    pub fn copy_with(&self, patch: EpisodeUpdate) -> Self {
        Self {
            anime_id: patch.anime_id.unwrap_or_else(|| self.anime_id.clone()),
            number: patch.number.unwrap_or_else(|| self.number.clone()),
            source_id: patch.source_id.or_else(|| self.source_id.clone()),
        }
    }
}