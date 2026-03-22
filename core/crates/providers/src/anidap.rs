use std::{
    collections::{HashMap, HashSet},
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
};

use aes_gcm::{Aes256Gcm, KeyInit, Nonce, aead::Aead};
use anyhow::{Result, anyhow};
use async_trait::async_trait;
use base64::{Engine as _, engine::general_purpose};
use chrono::{DateTime, TimeZone, Utc};
use regex::Regex;
use reqwest::{Client, Url};
use serde_json::Value;

use crate::traits::{SearchQuery, SourceOptions, StreamProvider};
use domain::{StreamSource, StreamableAnime, StreamingEpisode};

pub type NowUtcFn = Arc<dyn Fn() -> DateTime<Utc> + Send + Sync>;
pub type TokenDecoderFn = Arc<dyn Fn(&str) -> Result<String> + Send + Sync>;

#[derive(Clone)]
pub struct Anidap {
    client: Client,
    base_url: String,
    now_utc: NowUtcFn,
    token_decoder: Option<TokenDecoderFn>,
    decoder: Arc<AnidapDecoder>,
    session_primed: Arc<AtomicBool>,
}

impl Default for Anidap {
    fn default() -> Self {
        Self::new()
    }
}

impl Anidap {
    const DEFAULT_HOST: &'static str = "yuki";
    const DEFAULT_MODE: &'static str = "sub";
    const FALLBACK_HOSTS: [&'static str; 8] = [
        "nuri", "koto", "pahe", "ozzy", "dih", "mizu", "kami", "yuki",
    ];

    pub fn new() -> Self {
        let now_utc: NowUtcFn = Arc::new(Utc::now);
        Self {
            client: Client::new(),
            base_url: "https://anidap.se".to_string(),
            now_utc: now_utc.clone(),
            token_decoder: None,
            decoder: Arc::new(AnidapDecoder::new()),
            session_primed: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn with_client(client: Client) -> Self {
        Self {
            client,
            ..Self::new()
        }
    }

    pub fn with_hooks(
        client: Client,
        base_url: impl Into<String>,
        now_utc: Option<NowUtcFn>,
        token_decoder: Option<TokenDecoderFn>,
    ) -> Self {
        let now_utc = now_utc.unwrap_or_else(|| Arc::new(Utc::now));
        Self {
            client,
            base_url: base_url.into(),
            now_utc: now_utc.clone(),
            token_decoder,
            decoder: Arc::new(AnidapDecoder::new()),
            session_primed: Arc::new(AtomicBool::new(false)),
        }
    }

    fn watch_referer(&self, anime_id: &str, ep: &str, host: &str, mode: &str) -> Result<String> {
        let mut url = Url::parse(&format!("{}/watch", self.base_url.trim_end_matches('/')))?;
        url.query_pairs_mut()
            .append_pair("id", anime_id)
            .append_pair("ep", ep)
            .append_pair("provider", host)
            .append_pair("type", mode);
        Ok(url.to_string())
    }

    fn build_host_order(preferred_host: &str) -> Vec<String> {
        let mut out = vec![preferred_host.to_string()];
        for host in Self::FALLBACK_HOSTS {
            if !out.iter().any(|h| h == host) {
                out.push(host.to_string());
            }
        }
        out
    }

    fn base_headers() -> HashMap<&'static str, &'static str> {
        HashMap::from([
            (
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
            ),
            ("Accept", "application/json, text/plain, */*"),
        ])
    }

    fn origin_by_host(host: &str) -> Option<&'static str> {
        match host {
            "yuki" => Some("https://vidwish.live"),
            "kami" => Some("https://krussdomi.com"),
            "ozzy" => Some("https://megaup.live"),
            _ => None,
        }
    }

    fn apply_host_origin(url: &str, host: &str) -> String {
        let Some(origin) = Self::origin_by_host(host) else {
            return url.to_string();
        };
        if url.contains("origin=") {
            return url.to_string();
        }
        if url.contains('?') {
            format!("{url}&origin={origin}")
        } else {
            format!("{url}?origin={origin}")
        }
    }

    fn infer_type(url: &str) -> String {
        let lower = url.to_lowercase();
        if lower.contains(".mp4") {
            "mp4".to_string()
        } else {
            "hls".to_string()
        }
    }

    fn is_likely_playable_url(url: &str) -> bool {
        let lower = url.to_lowercase();
        if lower.contains(".m3u8") || lower.contains(".mp4") || lower.contains(".mpd") {
            return true;
        }
        if lower.contains("/storage/") {
            return true;
        }
        if lower.contains("cors.anidap.se/media/") {
            return false;
        }
        false
    }

    fn build_source(
        url: String,
        quality: Option<String>,
        kind: Option<String>,
        referer: String,
    ) -> StreamSource {
        StreamSource {
            url,
            quality: quality.unwrap_or_else(|| "auto".to_string()),
            kind: kind.unwrap_or_else(|| "hls".to_string()),
            headers: Some(HashMap::from([
                ("Referer".to_string(), referer),
                (
                    "User-Agent".to_string(),
                    Self::base_headers()
                        .get("User-Agent")
                        .copied()
                        .unwrap_or_default()
                        .to_string(),
                ),
            ])),
        }
    }

    async fn prime_session(&self) {
        if self.session_primed.swap(true, Ordering::SeqCst) {
            return;
        }
        let _ = self
            .get(
                Url::parse(&format!("{}/home", self.base_url.trim_end_matches('/')))
                    .expect("valid home URL"),
                None,
                false,
            )
            .await;
    }

    async fn get_json(&self, uri: Url, headers: Option<Vec<(&str, String)>>) -> Result<Value> {
        let body = self.get(uri, headers, true).await?;
        Ok(serde_json::from_str(&body)?)
    }

    async fn get(
        &self,
        uri: Url,
        headers: Option<Vec<(&str, String)>>,
        require_ok: bool,
    ) -> Result<String> {
        let mut req = self.client.get(uri);
        for (k, v) in Self::base_headers() {
            req = req.header(k, v);
        }
        if let Some(extra) = headers {
            for (k, v) in extra {
                req = req.header(k, v);
            }
        }

        let resp = req
            .timeout(std::time::Duration::from_secs(30))
            .send()
            .await?;
        if require_ok && !resp.status().is_success() {
            return Err(anyhow!(
                "Request failed with status {}",
                resp.status().as_u16()
            ));
        }
        Ok(resp.text().await?)
    }

    fn pick_title(value: &Value) -> String {
        if let Some(s) = value.as_str() {
            return s.to_string();
        }
        if !value.is_object() {
            return String::new();
        }
        for key in ["userPreferred", "english", "romaji", "native"] {
            if let Some(v) = value.get(key).and_then(Value::as_str) {
                if !v.is_empty() {
                    return v.to_string();
                }
            }
        }
        String::new()
    }

    fn to_i32(value: Option<&Value>) -> Option<i32> {
        match value {
            Some(Value::Number(n)) => n.as_i64().map(|v| v as i32),
            Some(Value::String(s)) => s.parse::<i32>().ok(),
            _ => None,
        }
    }

    async fn parse_source_payload(
        &self,
        payload: &Value,
        host: &str,
        referer: &str,
    ) -> Result<Vec<StreamSource>> {
        if payload.is_null() {
            return Ok(vec![]);
        }

        if let Some(raw) = payload.as_str() {
            if raw.starts_with("http") {
                return Ok(vec![Self::build_source(
                    Self::apply_host_origin(raw, host),
                    None,
                    Some(Self::infer_type(raw)),
                    referer.to_string(),
                )]);
            }
        }

        let decoded_payload = if let Some(token) = payload.as_str() {
            let decoded = if let Some(decoder) = &self.token_decoder {
                decoder(token)?
            } else {
                self.decoder.decode(token, (self.now_utc)())
            };

            if decoded.starts_with("http") {
                return Ok(vec![Self::build_source(
                    Self::apply_host_origin(&decoded, host),
                    None,
                    Some(Self::infer_type(&decoded)),
                    referer.to_string(),
                )]);
            }

            serde_json::from_str::<Value>(&decoded).unwrap_or(Value::String(decoded))
        } else {
            payload.clone()
        };

        let candidates = Self::extract_urls(&decoded_payload);
        Ok(candidates
            .into_iter()
            .map(|candidate| {
                let final_url = Self::apply_host_origin(&candidate.url, host);
                Self::build_source(
                    final_url.clone(),
                    candidate.quality,
                    candidate
                        .kind
                        .or_else(|| Some(Self::infer_type(&final_url))),
                    referer.to_string(),
                )
            })
            .collect())
    }

    fn extract_urls(payload: &Value) -> Vec<SourceCandidate> {
        let mut seen = HashSet::new();
        let mut out = Vec::new();
        let mut add = |url: Option<String>, quality: Option<String>, kind: Option<String>| {
            let Some(url) = url else {
                return;
            };
            if url.is_empty() || !seen.insert(url.clone()) {
                return;
            }
            out.push(SourceCandidate { url, quality, kind });
        };

        if let Some(map) = payload.as_object() {
            if let Some(sources) = map.get("sources").and_then(Value::as_array) {
                for source in sources {
                    if let Some(obj) = source.as_object() {
                        add(
                            obj.get("url").and_then(Value::as_str).map(str::to_string),
                            obj.get("quality")
                                .and_then(Value::as_str)
                                .map(str::to_string)
                                .or_else(|| {
                                    obj.get("label").and_then(Value::as_str).map(str::to_string)
                                }),
                            obj.get("type").and_then(Value::as_str).map(str::to_string),
                        );
                    }
                }
            }
            add(
                map.get("url").and_then(Value::as_str).map(str::to_string),
                None,
                None,
            );
            add(
                map.get("source")
                    .and_then(Value::as_str)
                    .map(str::to_string),
                None,
                None,
            );
        } else if let Some(list) = payload.as_array() {
            for item in list {
                if let Some(obj) = item.as_object() {
                    add(
                        obj.get("url").and_then(Value::as_str).map(str::to_string),
                        obj.get("quality")
                            .and_then(Value::as_str)
                            .map(str::to_string)
                            .or_else(|| {
                                obj.get("label").and_then(Value::as_str).map(str::to_string)
                            }),
                        obj.get("type").and_then(Value::as_str).map(str::to_string),
                    );
                } else if let Some(s) = item.as_str() {
                    add(Some(s.to_string()), None, None);
                }
            }
        }
        out
    }

    async fn fallback_watch_sources(
        &self,
        anime_id: &str,
        ep: &str,
        host: &str,
        mode: &str,
    ) -> Result<Vec<StreamSource>> {
        let referer = self.watch_referer(anime_id, ep, host, mode)?;
        let html = self
            .get(
                Url::parse(&referer)?,
                Some(vec![(
                    "Accept",
                    "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".to_string(),
                )]),
                true,
            )
            .await?;

        let m3u8_re = Regex::new(r#"https?://[^"'\s]+\.m3u8[^"'\s]*"#)?;
        let src_re = Regex::new(r#"src="(https?://[^"]+)""#)?;
        let mut urls = HashSet::<String>::new();

        for cap in m3u8_re.captures_iter(&html) {
            if let Some(url) = cap.get(0).map(|m| m.as_str().to_string()) {
                urls.insert(url);
            }
        }
        for cap in src_re.captures_iter(&html) {
            if let Some(url) = cap.get(1).map(|m| m.as_str().to_string()) {
                if url.contains(".m3u8") || url.contains("/storage/") {
                    urls.insert(url);
                }
            }
        }

        Ok(urls
            .into_iter()
            .map(|url| {
                let final_url = Self::apply_host_origin(&url, host);
                Self::build_source(
                    final_url.clone(),
                    None,
                    Some(Self::infer_type(&final_url)),
                    referer.clone(),
                )
            })
            .collect())
    }

    async fn get_sources_for_host(
        &self,
        anime_id: &str,
        ep: &str,
        mode: &str,
        host: &str,
    ) -> Result<Vec<StreamSource>> {
        let referer = self.watch_referer(anime_id, ep, host, mode)?;
        let mut uri = Url::parse(&format!(
            "{}/api/anime/sources",
            self.base_url.trim_end_matches('/')
        ))?;
        uri.query_pairs_mut()
            .append_pair("id", anime_id)
            .append_pair("ep", ep)
            .append_pair("host", host)
            .append_pair("type", mode);

        let source_resp = self
            .get_json(uri, Some(vec![("Referer", referer.clone())]))
            .await;

        match source_resp {
            Ok(data) => {
                let payload = data.get("data").cloned().unwrap_or(Value::Null);
                let parsed = self
                    .parse_source_payload(&payload, host, &referer)
                    .await
                    .unwrap_or_default();
                if !parsed.is_empty() {
                    return Ok(parsed);
                }
                self.fallback_watch_sources(anime_id, ep, host, mode).await
            }
            Err(_) => self.fallback_watch_sources(anime_id, ep, host, mode).await,
        }
    }
}

#[async_trait]
impl StreamProvider for Anidap {
    fn name(&self) -> &str {
        "Anidap"
    }

    async fn search(&self, query: SearchQuery<'_>) -> Result<Vec<StreamableAnime>> {
        self.prime_session().await;
        let mut url = Url::parse(&format!(
            "{}/api/anime/search",
            self.base_url.trim_end_matches('/')
        ))?;
        url.query_pairs_mut().append_pair("q", query.as_str());
        let referer = format!(
            "{}/search?q={}",
            self.base_url.trim_end_matches('/'),
            urlencoding::encode(query.as_str())
        );
        let data = self.get_json(url, Some(vec![("Referer", referer)])).await?;

        let results = data
            .get("data")
            .and_then(|v| v.get("results"))
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();

        Ok(results
            .into_iter()
            .map(|item| {
                let title = Self::pick_title(item.get("title").unwrap_or(&Value::Null));
                StreamableAnime {
                    id: item
                        .get("id")
                        .map(|v| v.to_string().trim_matches('"').to_string())
                        .unwrap_or_default(),
                    title: if title.is_empty() {
                        "Unknown".to_string()
                    } else {
                        title
                    },
                    available_episodes: Self::to_i32(item.get("currentEpisodeCount"))
                        .or_else(|| Self::to_i32(item.get("totalEpisodes"))),
                    season: None,
                    year: None,
                    media_type: None,
                    status: None,
                }
            })
            .collect())
    }

    async fn get_episodes(&self, anime: &StreamableAnime) -> Result<Vec<StreamingEpisode>> {
        self.prime_session().await;
        let mut uri = Url::parse(&format!(
            "{}/api/anime/{}/episodes",
            self.base_url.trim_end_matches('/'),
            anime.id
        ))?;
        uri.query_pairs_mut().append_pair("refresh", "false");
        let referer = self.watch_referer(&anime.id, "1", Self::DEFAULT_HOST, Self::DEFAULT_MODE)?;
        let data = self.get_json(uri, Some(vec![("Referer", referer)])).await?;

        let list = data
            .get("data")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        let mut episodes: Vec<StreamingEpisode> = list
            .into_iter()
            .map(|item| StreamingEpisode {
                anime_id: anime.id.clone(),
                number: item
                    .get("number")
                    .map(|v| v.to_string().trim_matches('"').to_string())
                    .unwrap_or_default(),
                source_id: None,
            })
            .collect();

        episodes.sort_by(|a, b| {
            let a_num = a.number.parse::<f64>().unwrap_or(0.0);
            let b_num = b.number.parse::<f64>().unwrap_or(0.0);
            a_num
                .partial_cmp(&b_num)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        Ok(episodes)
    }

    async fn get_sources(
        &self,
        episode: &StreamingEpisode,
        options: Option<&SourceOptions>,
    ) -> Result<Vec<StreamSource>> {
        self.prime_session().await;

        let mode = options
            .and_then(|o| o.mode.as_deref())
            .unwrap_or(Self::DEFAULT_MODE);
        let preferred_host = options
            .and_then(|o| o.host.as_deref())
            .unwrap_or(Self::DEFAULT_HOST);
        let hosts = Self::build_host_order(preferred_host);

        let mut best_effort = Vec::new();
        for host in hosts {
            let sources = self
                .get_sources_for_host(&episode.anime_id, &episode.number, mode, &host)
                .await
                .unwrap_or_default();
            if sources.is_empty() {
                continue;
            }

            let playable: Vec<StreamSource> = sources
                .iter()
                .filter(|s| Self::is_likely_playable_url(&s.url))
                .cloned()
                .collect();
            if !playable.is_empty() {
                return Ok(playable);
            }
            if best_effort.is_empty() {
                best_effort = sources;
            }
        }

        Ok(best_effort)
    }
}

#[derive(Debug, Clone)]
struct SourceCandidate {
    url: String,
    quality: Option<String>,
    kind: Option<String>,
}

#[derive(Clone)]
struct DerivedKeys {
    bucket: i64,
    aes_key: [u8; 32],
    xor_key: [u8; 16],
    expires_at: DateTime<Utc>,
}

struct AnidapDecoder {
    vt: [u8; 32],
    cache: Mutex<Option<DerivedKeys>>,
}

impl AnidapDecoder {
    const PERIOD_MS: i64 = ((6 * 6 * 6) + 47) * 60 * 1000;
    const BE: [u8; 32] = [
        13, 27, 7, 19, 31, 11, 23, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101,
        103, 107, 109, 113, 127, 131, 137, 139, 149, 151,
    ];

    fn new() -> Self {
        let mut vt = [0u8; 32];
        for (t, slot) in vt.iter_mut().enumerate() {
            let value =
                ((t as i64 * 17 + 53) ^ (t as i64 * 23 + 79) ^ (t as i64 * 31 + 124)) & 0xff;
            *slot = value as u8;
        }
        Self {
            vt,
            cache: Mutex::new(None),
        }
    }

    fn decode(&self, token: &str, now: DateTime<Utc>) -> String {
        let payload = match self.decode_base64_url(token) {
            Ok(v) => v,
            Err(_) => return token.to_string(),
        };

        if payload.len() < 28 {
            return latin1_decode(&payload);
        }

        let bucket = now.timestamp_millis() / Self::PERIOD_MS;
        for candidate in [bucket, bucket - 1] {
            let keys = match self.keys_for_bucket(candidate, now) {
                Ok(v) => v,
                Err(_) => continue,
            };
            let decrypted = match self.decrypt(&payload, &keys.aes_key) {
                Ok(v) => v,
                Err(_) => continue,
            };
            let unxored = self.xor(&decrypted, &keys.xor_key);
            return String::from_utf8(unxored)
                .unwrap_or_else(|e| String::from_utf8_lossy(e.as_bytes()).to_string());
        }

        latin1_decode(&payload)
    }

    fn decrypt(&self, payload: &[u8], key: &[u8; 32]) -> Result<Vec<u8>> {
        if payload.len() < 28 {
            return Err(anyhow!("Invalid encrypted payload"));
        }
        let nonce = Nonce::from_slice(&payload[..12]);
        let body = &payload[12..];
        let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| anyhow!("Invalid key"))?;
        let plaintext = cipher
            .decrypt(nonce, body)
            .map_err(|_| anyhow!("Decrypt failed"))?;
        Ok(plaintext)
    }

    fn keys_for_bucket(&self, bucket: i64, now: DateTime<Utc>) -> Result<DerivedKeys> {
        if let Some(cached) = self.cache.lock().expect("decoder cache lock").clone() {
            if cached.bucket == bucket && now < cached.expires_at {
                return Ok(cached);
            }
        }

        let derived = self.derive(bucket)?;
        *self.cache.lock().expect("decoder cache lock") = Some(derived.clone());
        Ok(derived)
    }

    fn derive(&self, bucket: i64) -> Result<DerivedKeys> {
        let mut t = [0u8; 128];
        for i in 0..128usize {
            let u = Self::BE[i % Self::BE.len()];
            t[i] = u8v(self.xt(i) as i64
                ^ u8v(bucket + i as i64 * u as i64) as i64
                ^ u8v((i as u8 ^ u) as i64) as i64);
        }

        let mut n = [0u8; 64];
        let mut r = [0u8; 32];
        let mut a = [0u8; 16];

        for i in 0..64usize {
            let u = t[i];
            let m = t[i + 64];
            let d = ie(u, m, u8v(bucket >> (i % 16)));
            n[i] = u8v((u ^ d) as i64);
        }

        for i in 0..32usize {
            let u = n[i];
            let m = n[i + 32];
            let d = Self::BE[(i * 3 + 7) % Self::BE.len()];
            r[i] = u8v((u ^ m ^ u8v(u as i64 + m as i64 + d as i64)) as i64);
        }

        for i in 0..16usize {
            let u = r[i];
            let m = r[i + 16];
            let d = u8v(((((u as u16) << 3) | ((u as u16) >> 5))
                ^ (((m as u16) << 5) | ((m as u16) >> 3))) as i64);
            a[i] = u8v((d ^ u8v(bucket >> (i * 2))) as i64);
        }

        let mut c = [0u8; 48];
        for i in 0..48usize {
            let u = (i * 7 + 11) % 32;
            let m = (i * 13 + 17) % 32;
            let d = (i * 19 + 23) % 32;
            let p = ie(r[u], r[m], r[d]);
            c[i] = u8v((p ^ u8v(bucket >> (i % 24)) ^ self.xt(i * 3)) as i64);
        }

        let mut l = [0u8; 32];
        for i in 0..3usize {
            for u in 0..32usize {
                let m = if i == 0 { c[u] } else { l[u] };
                let d = c[(u * 5 + 7) % 48];
                let p = c[(u * 11 + 13) % 48];
                let v = ie(m, d, p);
                l[u] = u8v((v ^ c[(u + i * 16) % 48]) as i64);
            }
        }

        let expires_ts = (bucket + 1) * Self::PERIOD_MS;
        let expires_at = Utc
            .timestamp_millis_opt(expires_ts)
            .single()
            .ok_or_else(|| anyhow!("Invalid timestamp"))?;

        Ok(DerivedKeys {
            bucket,
            aes_key: l,
            xor_key: a,
            expires_at,
        })
    }

    fn xor(&self, input: &[u8], key: &[u8; 16]) -> Vec<u8> {
        let mut out = vec![0u8; input.len()];
        for i in 0..input.len() {
            let a = i % key.len();
            let c = key[a];
            let shift = i % 8;
            let left = (((c as u16) << shift) & 0xff) as u8;
            let right = if shift == 0 {
                0
            } else {
                ((c as u16) >> (8 - shift)) as u8
            };
            let l = left | right;
            let j = u8v((i as i64 * 7) + 13);
            out[i] = u8v((input[i] ^ l ^ j ^ key[(a + 1) % key.len()]) as i64);
        }
        out
    }

    fn xt(&self, index: usize) -> u8 {
        u8v(self.vt[index % self.vt.len()] as i64
            ^ self.vt[(index * 7 + 11) % self.vt.len()] as i64
            ^ self.vt[(index * 13 + 17) % self.vt.len()] as i64)
    }

    fn decode_base64_url(&self, value: &str) -> Result<Vec<u8>> {
        let mut normalized = value.replace('-', "+").replace('_', "/");
        while normalized.len() % 4 != 0 {
            normalized.push('=');
        }
        Ok(general_purpose::STANDARD.decode(normalized)?)
    }
}

fn ie(e: u8, t: u8, n: u8) -> u8 {
    u8v((((e ^ t) as u16) << 1 ^ (((t ^ n) as u16) >> 1) ^ (e as u16 + t as u16 + n as u16)) as i64)
}

fn u8v(value: i64) -> u8 {
    (value & 0xff) as u8
}

fn latin1_decode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| char::from(*b)).collect()
}