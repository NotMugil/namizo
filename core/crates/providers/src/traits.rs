use std::borrow::Cow;
use anyhow::Result;
use async_trait::async_trait;
use serde::{Serialize, Deserialize};
use domain::{StreamingEpisode, StreamSource, StreamableAnime};

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceOptions {
    pub mode: Option<String>,
    pub host: Option<String>,
}

#[derive(Debug, Clone)]
pub struct SearchQuery<'a> {
    value: Cow<'a, str>,
}

impl<'a> SearchQuery<'a> {
    pub fn as_str(&self) -> &str {
        &self.value
    }
}

impl<'a> From<&'a str> for SearchQuery<'a> {
    fn from(value: &'a str) -> Self {
        Self { value: Cow::Borrowed(value) }
    }
}

impl From<String> for SearchQuery<'_> {
    fn from(value: String) -> Self {
        Self { value: Cow::Owned(value) }
    }
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