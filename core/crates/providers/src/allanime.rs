use std::collections::BTreeSet;

use anyhow::{anyhow, Result};
use async_trait::async_trait;
use regex::Regex;
use reqwest::{Client, Url};
use serde_json::{json, Value};

use domain::{StreamingEpisode, StreamSource, StreamableAnime};
use crate::traits::{SearchQuery, SourceOptions, StreamProvider};
use crate::utils::decryptor::decrypt;

#[derive(Clone)]
pub struct AllAnime {
    client: Client,
    api_url: String,
    referer: String,
    source_base_url: String,
}

impl Default for AllAnime {
    fn default() -> Self {
        Self::new()
    }
}

impl AllAnime {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            api_url: "https://api.allanime.day/api".to_string(),
            referer: "https://allmanga.to".to_string(),
            source_base_url: "https://allanime.day".to_string(),
        }
    }

    pub fn with_client(client: Client) -> Self {
        Self {
            client,
            ..Self::new()
        }
    }

    pub fn with_config(
        client: Client,
        api_url: impl Into<String>,
        referer: impl Into<String>,
        source_base_url: impl Into<String>,
    ) -> Self {
        Self {
            client,
            api_url: api_url.into(),
            referer: referer.into(),
            source_base_url: source_base_url.into(),
        }
    }

    fn gql_url(&self, query: &str, variables: Value) -> Result<Url> {
        let mut url = Url::parse(&self.api_url)?;
        url.query_pairs_mut()
            .append_pair("variables", &variables.to_string())
            .append_pair("query", query);
        Ok(url)
    }

    async fn process_source(&self, source: &Value) -> Result<Vec<StreamSource>> {
        let source_url = source
            .get("sourceUrl")
            .and_then(Value::as_str)
            .unwrap_or_default();
        if source_url.is_empty() {
            return Ok(vec![]);
        }

        let source_name = source
            .get("sourceName")
            .and_then(Value::as_str)
            .unwrap_or("unknown");

        let decrypted_id = if source_url.starts_with("--") {
            decrypt(&source_url[2..])
        } else {
            source_url.to_string()
        };

        let endpoint = format!("{}{}", self.source_base_url, decrypted_id);
        let response = self
            .client
            .get(endpoint)
            .header("Referer", &self.referer)
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0",
            )
            .send()
            .await?;

        if !response.status().is_success() {
            return Ok(vec![]);
        }

        let body = response.text().await?;
        self.parse_links(&body, source_name).await
    }

    async fn parse_links(&self, response_body: &str, _source_name: &str) -> Result<Vec<StreamSource>> {
        let mut sources: Vec<StreamSource> = Vec::new();

        let referer_match = Regex::new(r#""Referer":"([^"]*)""#)?
            .captures(response_body)
            .and_then(|cap| cap.get(1).map(|m| m.as_str().to_string()));

        let direct_re = Regex::new(r#""link":"([^"]*)".*?"resolutionStr":"([^"]*)""#)?;
        for cap in direct_re.captures_iter(response_body) {
            let mut url = cap
                .get(1)
                .map(|m| m.as_str().replace(r"\/", "/"))
                .unwrap_or_default();
            let quality = cap
                .get(2)
                .map(|m| m.as_str().to_string())
                .unwrap_or_else(|| "auto".to_string());

            if url.contains(".m3u8") {
                self.parse_m3u8(&url, referer_match.as_deref(), &mut sources)
                    .await?;
            } else if !url.is_empty() {
                sources.push(StreamSource {
                    url: std::mem::take(&mut url),
                    quality,
                    kind: "mp4".to_string(),
                    headers: None,
                });
            }
        }

        let hls_re = Regex::new(r#""hls","url":"([^"]*)".*?"hardsub_lang":"en-US""#)?;
        for cap in hls_re.captures_iter(response_body) {
            let url = cap
                .get(1)
                .map(|m| m.as_str().replace(r"\/", "/"))
                .unwrap_or_default();
            if url.is_empty() {
                continue;
            }
            if url.contains("master.m3u8") {
                self.parse_m3u8(&url, referer_match.as_deref(), &mut sources)
                    .await?;
            } else {
                sources.push(StreamSource {
                    url,
                    quality: "auto".to_string(),
                    kind: "hls".to_string(),
                    headers: None,
                });
            }
        }

        Ok(sources)
    }

    async fn parse_m3u8(
        &self,
        url: &str,
        referer: Option<&str>,
        sources: &mut Vec<StreamSource>,
    ) -> Result<()> {
        let response = self
            .client
            .get(url)
            .header("Referer", referer.unwrap_or(&self.referer))
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0",
            )
            .send()
            .await;

        let Ok(response) = response else {
            sources.push(StreamSource {
                url: url.to_string(),
                quality: "auto".to_string(),
                kind: "hls".to_string(),
                headers: None,
            });
            return Ok(());
        };

        if !response.status().is_success() {
            sources.push(StreamSource {
                url: url.to_string(),
                quality: "auto".to_string(),
                kind: "hls".to_string(),
                headers: None,
            });
            return Ok(());
        }

        let body = response.text().await.unwrap_or_default();
        let lines: Vec<&str> = body.lines().collect();
        let res_re = Regex::new(r"RESOLUTION=(\d+x\d+)")?;

        let mut found_stream = false;
        for (i, line) in lines.iter().enumerate() {
            if !line.starts_with("#EXT-X-STREAM-INF") {
                continue;
            }
            let quality = res_re
                .captures(line)
                .and_then(|cap| cap.get(1).map(|m| m.as_str().to_string()))
                .unwrap_or_else(|| "auto".to_string());

            if let Some(next_line) = lines.get(i + 1) {
                let mut stream_url = next_line.trim().to_string();
                if !stream_url.is_empty() && !stream_url.starts_with('#') {
                    if !stream_url.starts_with("http") {
                        if let Some((base, _)) = url.rsplit_once('/') {
                            stream_url = format!("{base}/{stream_url}");
                        }
                    }
                    sources.push(StreamSource {
                        url: stream_url,
                        quality,
                        kind: "hls".to_string(),
                        headers: None,
                    });
                    found_stream = true;
                }
            }
        }

        if !found_stream {
            sources.push(StreamSource {
                url: url.to_string(),
                quality: "auto".to_string(),
                kind: "hls".to_string(),
                headers: None,
            });
        }

        Ok(())
    }
}

#[async_trait]
impl StreamProvider for AllAnime {
    fn name(&self) -> &str {
        "AllAnime"
    }

    async fn search(&self, query: SearchQuery<'_>) -> Result<Vec<StreamableAnime>> {
        let search_query = query.as_str();
        let search_gql = "query( $search: SearchInput $limit: Int $page: Int $translationType: VaildTranslationTypeEnumType $countryOrigin: VaildCountryOriginEnumType ) { shows( search: $search limit: $limit page: $page translationType: $translationType countryOrigin: $countryOrigin ) { edges { _id name availableEpisodes __typename } }}";
        let variables = json!({
            "search": { "allowAdult": false, "allowUnknown": false, "query": search_query },
            "limit": 40,
            "page": 1,
            "translationType": "sub",
            "countryOrigin": "ALL"
        });

        let uri = self.gql_url(search_gql, variables)?;
        let response = self
            .client
            .get(uri)
            .header("Referer", &self.referer)
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0",
            )
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow!(
                "Failed to search anime: {}",
                response.status().as_u16()
            ));
        }

        let data = response.json::<Value>().await?;
        let edges = data
            .get("data")
            .and_then(|v| v.get("shows"))
            .and_then(|v| v.get("edges"))
            .and_then(Value::as_array);

        let Some(edges) = edges else {
            return Ok(vec![]);
        };

        let mut results = Vec::with_capacity(edges.len());
        for item in edges {
            let available_episodes = if let Some(value) = item.get("availableEpisodes") {
                if let Some(raw) = value.as_i64() {
                    Some(raw as i32)
                } else if let Some(map) = value.as_object() {
                    map.get("sub")
                        .and_then(Value::as_i64)
                        .or_else(|| map.get("dub").and_then(Value::as_i64))
                        .map(|v| v as i32)
                } else {
                    None
                }
            } else {
                None
            };

            results.push(StreamableAnime {
                id: item
                    .get("_id")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string(),
                title: item
                    .get("name")
                    .and_then(Value::as_str)
                    .unwrap_or("Unknown")
                    .to_string(),
                available_episodes,
            });
        }
        Ok(results)
    }

    async fn get_episodes(&self, anime: &StreamableAnime) -> Result<Vec<StreamingEpisode>> {
        let episodes_list_gql =
            "query ($showId: String!) { show( _id: $showId ) { _id availableEpisodesDetail }}";
        let variables = json!({ "showId": anime.id });
        let uri = self.gql_url(episodes_list_gql, variables)?;

        let response = self
            .client
            .get(uri)
            .header("Referer", &self.referer)
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0",
            )
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow!(
                "Failed to get episodes: {}",
                response.status().as_u16()
            ));
        }

        let data = response.json::<Value>().await?;
        let detail = data
            .get("data")
            .and_then(|v| v.get("show"))
            .and_then(|v| v.get("availableEpisodesDetail"));
        let Some(detail) = detail else {
            return Ok(vec![]);
        };

        let mut numbers = BTreeSet::<String>::new();
        for key in ["sub", "dub", "raw"] {
            if let Some(values) = detail.get(key).and_then(Value::as_array) {
                for value in values {
                    if let Some(number) = value.as_str() {
                        numbers.insert(number.to_string());
                    }
                }
            }
        }

        let mut sorted: Vec<String> = numbers.into_iter().collect();
        sorted.sort_by(|a, b| {
            let a_num = a.parse::<f64>().unwrap_or(0.0);
            let b_num = b.parse::<f64>().unwrap_or(0.0);
            a_num
                .partial_cmp(&b_num)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        Ok(sorted
            .into_iter()
            .map(|number| StreamingEpisode {
                anime_id: anime.id.clone(),
                number,
                source_id: None,
            })
            .collect())
    }

    async fn get_sources(
        &self,
        episode: &StreamingEpisode,
        options: Option<&SourceOptions>,
    ) -> Result<Vec<StreamSource>> {
        let mode = options
            .and_then(|o| o.mode.clone())
            .unwrap_or_else(|| "sub".to_string());
        let episode_embed_gql = "query ($showId: String!, $translationType: VaildTranslationTypeEnumType!, $episodeString: String!) { episode( showId: $showId translationType: $translationType episodeString: $episodeString ) { episodeString sourceUrls }}";
        let variables = json!({
            "showId": episode.anime_id,
            "translationType": mode,
            "episodeString": episode.number,
        });

        let uri = self.gql_url(episode_embed_gql, variables)?;
        let response = self
            .client
            .get(uri)
            .header("Referer", &self.referer)
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0",
            )
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow!(
                "Failed to get episode sources: {}",
                response.status().as_u16()
            ));
        }

        let data = response.json::<Value>().await?;
        let source_urls = data
            .get("data")
            .and_then(|v| v.get("episode"))
            .and_then(|v| v.get("sourceUrls"))
            .and_then(Value::as_array);

        let Some(source_urls) = source_urls else {
            return Ok(vec![]);
        };

        let mut all = Vec::new();
        for source in source_urls {
            if let Ok(mut parsed) = self.process_source(source).await {
                all.append(&mut parsed);
            }
        }
        Ok(all)
    }
}

#[derive(Clone, Default)]
pub struct AllManga {
    inner: AllAnime,
}

impl AllManga {
    pub fn new() -> Self {
        Self {
            inner: AllAnime::new(),
        }
    }

    pub fn with_inner(inner: AllAnime) -> Self {
        Self { inner }
    }
}

#[async_trait]
impl StreamProvider for AllManga {
    fn name(&self) -> &str {
        "AllManga"
    }

    async fn search(&self, query: SearchQuery<'_>) -> Result<Vec<StreamableAnime>> {
        self.inner.search(query).await
    }

    async fn get_episodes(&self, anime: &StreamableAnime) -> Result<Vec<StreamingEpisode>> {
        self.inner.get_episodes(anime).await
    }

    async fn get_sources(
        &self,
        episode: &StreamingEpisode,
        options: Option<&SourceOptions>,
    ) -> Result<Vec<StreamSource>> {
        self.inner.get_sources(episode, options).await
    }
}
