use anyhow::{anyhow, Result};
use async_trait::async_trait;
use regex::Regex;
use reqwest::{Client, Url};
use scraper::{Html, Selector};

use domain::{StreamingEpisode, StreamSource, StreamableAnime};
use crate::traits::{SearchQuery, SourceOptions, StreamProvider};

#[derive(Clone)]
pub struct Anizone {
    client: Client,
    base_url: String,
}

impl Default for Anizone {
    fn default() -> Self {
        Self::new()
    }
}

impl Anizone {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: "https://anizone.to".to_string(),
        }
    }

    pub fn with_client(client: Client) -> Self {
        Self {
            client,
            ..Self::new()
        }
    }

    pub fn with_base_url(client: Client, base_url: impl Into<String>) -> Self {
        Self {
            client,
            base_url: base_url.into(),
        }
    }

    fn headers() -> Vec<(&'static str, &'static str)> {
        vec![
            (
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            ),
            (
                "Accept",
                "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
            ),
        ]
    }

    async fn get_html(&self, url: Url) -> Result<String> {
        let mut req = self.client.get(url);
        for (k, v) in Self::headers() {
            req = req.header(k, v);
        }
        let response = req.send().await?;
        if !response.status().is_success() {
            return Err(anyhow!("Request failed: {}", response.status().as_u16()));
        }
        Ok(response.text().await?)
    }
}

#[async_trait]
impl StreamProvider for Anizone {
    fn name(&self) -> &str {
        "Anizone"
    }

    async fn search(&self, query: SearchQuery<'_>) -> Result<Vec<StreamableAnime>> {
        let mut url = Url::parse(&format!("{}/anime", self.base_url.trim_end_matches('/')))?;
        url.query_pairs_mut().append_pair("search", query.as_str());
        let html = self.get_html(url).await?;
        let doc = Html::parse_document(&html);

        let root_selector =
            Selector::parse("div.grid > div.relative.overflow-hidden").expect("valid selector");
        let title_selector = Selector::parse("a[title]").expect("valid selector");
        let info_selector = Selector::parse(".text-xs").expect("valid selector");
        let eps_re = Regex::new(r"(\d+)\s*Eps")?;

        let mut out = Vec::new();
        for item in doc.select(&root_selector) {
            let Some(title_el) = item.select(&title_selector).next() else {
                continue;
            };
            let href = title_el.value().attr("href").unwrap_or_default().to_string();
            let title = title_el.value().attr("title").unwrap_or_default().to_string();
            let info = item
                .select(&info_selector)
                .next()
                .map(|e| e.text().collect::<String>())
                .unwrap_or_default();
            let available = eps_re
                .captures(&info)
                .and_then(|cap| cap.get(1))
                .and_then(|m| m.as_str().parse::<i32>().ok());

            out.push(StreamableAnime {
                id: href,
                title,
                available_episodes: available,
            });
        }
        Ok(out)
    }

    async fn get_episodes(&self, anime: &StreamableAnime) -> Result<Vec<StreamingEpisode>> {
        let html = self.get_html(Url::parse(&anime.id)?).await?;
        let doc = Html::parse_document(&html);
        let list_selector = Selector::parse("ul.grid li a").expect("valid selector");
        let h3_selector = Selector::parse("h3").expect("valid selector");
        let num_re = Regex::new(r"Episode\s+(\d+(\.\d+)?)")?;

        let mut episodes = Vec::new();
        for anchor in doc.select(&list_selector) {
            let href = anchor.value().attr("href").unwrap_or_default().to_string();
            let title = anchor
                .select(&h3_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string())
                .unwrap_or_else(|| "Unknown".to_string());

            let number = num_re
                .captures(&title)
                .and_then(|cap| cap.get(1))
                .map(|m| m.as_str().to_string())
                .unwrap_or(title);

            episodes.push(StreamingEpisode {
                anime_id: anime.id.clone(),
                number,
                source_id: Some(href),
            });
        }
        Ok(episodes)
    }

    async fn get_sources(
        &self,
        episode: &StreamingEpisode,
        _options: Option<&SourceOptions>,
    ) -> Result<Vec<StreamSource>> {
        let Some(source_id) = episode.source_id.as_deref() else {
            return Ok(vec![]);
        };
        let html = self.get_html(Url::parse(source_id)?).await?;
        let doc = Html::parse_document(&html);
        let player_selector = Selector::parse("media-player").expect("valid selector");
        let Some(player) = doc.select(&player_selector).next() else {
            return Ok(vec![]);
        };

        let stream_url = player.value().attr("src").unwrap_or_default().to_string();
        if stream_url.is_empty() {
            return Ok(vec![]);
        }

        let kind = if stream_url.ends_with(".mp4") {
            "mp4"
        } else {
            "hls"
        };

        Ok(vec![StreamSource {
            url: stream_url,
            quality: "default".to_string(),
            kind: kind.to_string(),
            headers: Some(std::collections::HashMap::from([
                (
                    "User-Agent".to_string(),
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".to_string(),
                ),
                (
                    "Accept".to_string(),
                    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8".to_string(),
                ),
            ])),
        }])
    }
}
