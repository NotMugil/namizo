use anyhow::Result;
use async_trait::async_trait;
use domain::{StreamSource, StreamableAnime, StreamingEpisode};
use serde::{Deserialize, Serialize};

pub struct SearchQuery<'a>(&'a str);

impl<'a> SearchQuery<'a> {
    pub fn as_str(&self) -> &str {
        self.0
    }
}

impl<'a> From<&'a str> for SearchQuery<'a> {
    fn from(s: &'a str) -> Self {
        Self(s)
    }
}

impl<'a> From<&'a String> for SearchQuery<'a> {
    fn from(s: &'a String) -> Self {
        Self(s.as_str())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceOptions {
    pub mode: Option<String>,
    pub host: Option<String>,
}

#[async_trait]
pub trait StreamProvider: Send + Sync {
    fn name(&self) -> &str;
    async fn search(&self, query: SearchQuery<'_>) -> Result<Vec<StreamableAnime>>;
    async fn get_episodes(&self, anime: &StreamableAnime) -> Result<Vec<StreamingEpisode>>;
    async fn get_sources(
        &self,
        episode: &StreamingEpisode,
        options: Option<&SourceOptions>,
    ) -> Result<Vec<StreamSource>>;
}
