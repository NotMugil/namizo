use thiserror::Error;

#[derive(Debug, Error)]
pub enum TvdbError {
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),

    #[error("Auth failed: {0}")]
    Auth(String),

    #[error("Not found: tvdb_id={0}")]
    NotFound(u64),

    #[error("Mapping not found for anilist_id={0}")]
    MappingNotFound(u32),

    #[error("Parse error: {0}")]
    Parse(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Skipped: {0}")]
    Skipped(String),
}