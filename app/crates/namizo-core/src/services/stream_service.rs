use anyhow::Result;
use domain::StreamSource;

const DEMO_URL: &str = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8";

pub struct StreamService;

impl StreamService {
    pub fn new() -> Self {
        Self
    }

    pub async fn get_episode_sources(
        &self,
        _anime_title: &str,
        _episode_num: f64,
        _mode: &str,
    ) -> Result<Vec<StreamSource>> {
        Ok(vec![StreamSource {
            url: DEMO_URL.to_string(),
            quality: "Demo".to_string(),
            kind: "hls".to_string(),
            headers: None,
        }])
    }
}

impl Default for StreamService {
    fn default() -> Self {
        Self::new()
    }
}
