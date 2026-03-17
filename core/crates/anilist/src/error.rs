use thiserror::Error;

#[derive(Debug, Error)]
pub enum AnilistError {
    #[error("HTTP request failed: {0}")]
    Http(#[from] reqwest::Error),

    #[error("Failed to parse response: {0}")]
    Parse(String),
}