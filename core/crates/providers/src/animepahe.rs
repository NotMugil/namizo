use anyhow::{anyhow, Result};
use async_trait::async_trait;
use regex::Regex;
use reqwest::{Client, Url};
use scraper::{Html, Selector};
use serde_json::Value;

use domain::{StreamingEpisode, StreamSource, StreamableAnime};
use crate::traits::{SearchQuery, SourceOptions, StreamProvider};
use crate::utils::{packer::unpack, string_utils::generate_random_string};

#[derive(Clone)]
pub struct AnimePahe {
    client: Client,
    base_url: String,
    cookie: String,
}

impl Default for AnimePahe {
    fn default() -> Self {
        Self::new()
    }
}

impl AnimePahe {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: "https://animepahe.si".to_string(),
            cookie: format!("__ddg2_={}", generate_random_string(16)),
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
            cookie: format!("__ddg2_={}", generate_random_string(16)),
        }
    }

    async fn get(&self, uri: Url, headers: Option<Vec<(&str, String)>>) -> Result<String> {
        let mut request = self
            .client
            .get(uri)
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
            )
            .header("Cookie", &self.cookie);

        if let Some(extra_headers) = headers {
            for (key, value) in extra_headers {
                request = request.header(key, value);
            }
        }

        let response = request.send().await?;
        if !response.status().is_success() {
            return Err(anyhow!(
                "Request failed with status {}",
                response.status().as_u16()
            ));
        }

        Ok(response.text().await?)
    }

    async fn get_json(&self, uri: Url) -> Result<Value> {
        let body = self.get(uri, None).await?;
        Ok(serde_json::from_str(&body)?)
    }

    fn build_api_url(&self, params: &[(&str, String)]) -> Result<Url> {
        let mut url = Url::parse(&format!("{}/api", self.base_url.trim_end_matches('/')))?;
        for (k, v) in params {
            url.query_pairs_mut().append_pair(k, v);
        }
        Ok(url)
    }

    async fn process_embed(&self, url: &str, quality: &str) -> Result<Option<StreamSource>> {
        let body = self
            .get(
                Url::parse(url)?,
                Some(vec![("Referer", self.base_url.clone())]),
            )
            .await?;

        let script_re = Regex::new(
            r#"(?s)eval\(function\(p,a,c,k,e,d\).*?\}\((.*?\.split\(['"]\|['"]\),\d+,.*?)\)\)"#,
        )?;
        let source_re = Regex::new(r#"source\s*=\s*['"](.*?)['"]"#)?;

        for cap in script_re.captures_iter(&body) {
            let Some(args) = cap.get(1).map(|m| m.as_str()) else {
                continue;
            };
            let unpacked = unpack(args);
            if let Some(source_match) = source_re.captures(&unpacked) {
                if let Some(url) = source_match.get(1).map(|m| m.as_str()) {
                    return Ok(Some(StreamSource {
                        url: url.to_string(),
                        quality: quality.to_string(),
                        kind: "hls".to_string(),
                        headers: Some(std::collections::HashMap::from([(
                            "Referer".to_string(),
                            "https://kwik.cx/".to_string(),
                        )])),
                    }));
                }
            }
        }

        Ok(None)
    }
}

#[async_trait]
impl StreamProvider for AnimePahe {
    fn name(&self) -> &str {
        "AnimePahe"
    }

    async fn search(&self, query: SearchQuery<'_>) -> Result<Vec<StreamableAnime>> {
        let url = self.build_api_url(&[
            ("m", "search".to_string()),
            ("q", query.as_str().to_string()),
        ])?;
        let data = self.get_json(url).await?;

        if data.get("total").and_then(Value::as_i64).unwrap_or_default() == 0 {
            return Ok(vec![]);
        }

        let list = data.get("data").and_then(Value::as_array).cloned().unwrap_or_default();
        Ok(list
            .into_iter()
            .map(|e| StreamableAnime {
                id: e
                    .get("session")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string(),
                title: e
                    .get("title")
                    .and_then(Value::as_str)
                    .unwrap_or("Unknown")
                    .to_string(),
                available_episodes: e.get("episodes").and_then(Value::as_i64).map(|v| v as i32),
            })
            .collect())
    }

    async fn get_episodes(&self, anime: &StreamableAnime) -> Result<Vec<StreamingEpisode>> {
        let mut episodes = Vec::new();
        let mut page = 1i32;
        let mut last_page = 1i32;

        while page <= last_page {
            let url = self.build_api_url(&[
                ("m", "release".to_string()),
                ("id", anime.id.clone()),
                ("sort", "episode_asc".to_string()),
                ("page", page.to_string()),
            ])?;

            let data = self.get_json(url).await?;
            last_page = data.get("last_page").and_then(Value::as_i64).unwrap_or(1) as i32;

            let list = data.get("data").and_then(Value::as_array).cloned().unwrap_or_default();
            for item in list {
                episodes.push(StreamingEpisode {
                    anime_id: anime.id.clone(),
                    number: item
                        .get("episode")
                        .map(|v| v.to_string().trim_matches('"').to_string())
                        .unwrap_or_else(|| "0".to_string()),
                    source_id: item.get("session").and_then(Value::as_str).map(str::to_string),
                });
            }

            page += 1;
        }

        Ok(episodes)
    }

    async fn get_sources(
        &self,
        episode: &StreamingEpisode,
        options: Option<&SourceOptions>,
    ) -> Result<Vec<StreamSource>> {
        let Some(source_id) = episode.source_id.as_deref() else {
            return Err(anyhow!("Episode ID (session) is required for AnimePahe"));
        };

        let mode = options
            .and_then(|o| o.mode.clone())
            .unwrap_or_else(|| "sub".to_string());
        let target_audio = if mode == "dub" { "eng" } else { "jpn" };

        let page = Url::parse(&format!(
            "{}/play/{}/{}",
            self.base_url.trim_end_matches('/'),
            episode.anime_id,
            source_id
        ))?;

        let html = self
            .get(page, Some(vec![("Referer", self.base_url.clone())]))
            .await?;
        let candidates: Vec<(String, String)> = {
            let doc = Html::parse_document(&html);
            let selector = Selector::parse("#resolutionMenu > button").expect("valid selector");

            doc.select(&selector)
                .filter_map(|button| {
                    let audio = button.value().attr("data-audio");
                    if let Some(audio) = audio {
                        if audio != target_audio {
                            return None;
                        }
                    }

                    let resolution = button
                        .value()
                        .attr("data-resolution")
                        .unwrap_or("unknown")
                        .to_string();
                    let src = button.value().attr("data-src");
                    let kwik = button.value().attr("data-kwik");
                    let url = src.or(kwik)?.to_string();
                    Some((url, resolution))
                })
                .collect()
        };

        let mut sources = Vec::new();
        for (url, resolution) in candidates {
            if let Ok(Some(source)) = self.process_embed(&url, &resolution).await {
                sources.push(source);
            }
        }

        Ok(sources)
    }
}
