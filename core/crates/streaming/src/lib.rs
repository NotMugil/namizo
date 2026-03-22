use std::{
    collections::HashMap,
    sync::{Arc, LazyLock},
    time::{Duration, Instant},
};

use axum::{
    Router,
    body::Body,
    extract::{Path, State},
    http::{
        HeaderMap, HeaderValue, StatusCode,
        header::{
            ACCEPT_RANGES, ACCESS_CONTROL_ALLOW_ORIGIN, CONTENT_LENGTH, CONTENT_RANGE,
            CONTENT_TYPE, RANGE,
        },
    },
    response::Response,
    routing::get,
};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use domain::StreamSource;
use rand::{Rng, distributions::Alphanumeric};
use regex::Regex;
use reqwest::{Client, Url};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use tokio::{net::TcpListener, sync::RwLock};

const SESSION_TTL: Duration = Duration::from_secs(60 * 60);
static HLS_URI_ATTR_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)URI=(?:"([^"]+)"|'([^']+)')"#).expect("valid HLS URI attribute regex")
});

#[derive(Debug, Error)]
pub enum PlaybackError {
    #[error("failed to bind playback proxy listener: {0}")]
    Bind(#[from] std::io::Error),
    #[error("invalid proxy target url: {0}")]
    InvalidUrl(#[from] url::ParseError),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaybackStart {
    pub url: String,
    pub kind: String,
    pub session_id: Option<String>,
    pub proxied: bool,
}

#[derive(Clone)]
struct ProxyState {
    client: Client,
    sessions: Arc<RwLock<HashMap<String, PlaybackSession>>>,
}

#[derive(Clone)]
struct PlaybackSession {
    source_url: String,
    source_kind: String,
    headers: HashMap<String, String>,
    created_at: Instant,
}

#[derive(Clone)]
pub struct PlaybackService {
    proxy_state: ProxyState,
    base_url: String,
}

impl PlaybackService {
    pub async fn new() -> Result<Self, PlaybackError> {
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let addr = listener.local_addr()?;
        let state = ProxyState {
            client: Client::new(),
            sessions: Arc::new(RwLock::new(HashMap::new())),
        };

        let router = Router::new()
            .route("/play/{session_id}", get(proxy_source))
            .route("/play/{session_id}/{*rest}", get(proxy_tail))
            .with_state(state.clone());

        tokio::spawn(async move {
            if let Err(error) = axum::serve(listener, router).await {
                eprintln!("[playback] proxy server stopped: {error}");
            }
        });

        Ok(Self {
            proxy_state: state,
            base_url: format!("http://127.0.0.1:{}", addr.port()),
        })
    }

    pub async fn start(&self, source: StreamSource) -> PlaybackStart {
        self.cleanup_expired_sessions().await;
        let headers = source.headers.unwrap_or_default();
        let session_id = random_session_id();
        eprintln!(
            "[playback_start] session_id={} kind={} source_url={} headers={:?}",
            session_id, source.kind, source.url, headers
        );
        self.proxy_state.sessions.write().await.insert(
            session_id.clone(),
            PlaybackSession {
                source_url: source.url,
                source_kind: source.kind.clone(),
                headers,
                created_at: Instant::now(),
            },
        );

        PlaybackStart {
            url: format!("{}/play/{}", self.base_url, session_id),
            kind: source.kind,
            session_id: Some(session_id),
            proxied: true,
        }
    }

    pub async fn stop(&self, session_id: Option<&str>) {
        if let Some(id) = session_id {
            eprintln!("[playback_stop] session_id={id}");
            self.proxy_state.sessions.write().await.remove(id);
        } else {
            eprintln!("[playback_stop] cleanup_expired_sessions");
            self.cleanup_expired_sessions().await;
        }
    }

    async fn cleanup_expired_sessions(&self) {
        let now = Instant::now();
        self.proxy_state
            .sessions
            .write()
            .await
            .retain(|_, session| now.duration_since(session.created_at) <= SESSION_TTL);
    }
}

async fn proxy_source(
    State(state): State<ProxyState>,
    Path(session_id): Path<String>,
    headers: HeaderMap,
) -> Response<Body> {
    proxy_request(state, session_id, None, headers).await
}

async fn proxy_tail(
    State(state): State<ProxyState>,
    Path((session_id, rest)): Path<(String, String)>,
    headers: HeaderMap,
) -> Response<Body> {
    proxy_request(state, session_id, Some(rest), headers).await
}

async fn proxy_request(
    state: ProxyState,
    session_id: String,
    rest: Option<String>,
    incoming_headers: HeaderMap,
) -> Response<Body> {
    let session = {
        let sessions = state.sessions.read().await;
        sessions.get(&session_id).cloned()
    };

    let Some(session) = session else {
        eprintln!("[playback_proxy] session_id={} not found", session_id);
        return simple_response(StatusCode::NOT_FOUND, "Playback session not found");
    };

    let target_url = match resolve_target_url(&session, rest.as_deref()) {
        Ok(url) => url,
        Err(error) => {
            eprintln!(
                "[playback_proxy] session_id={} invalid target rest={:?}: {}",
                session_id, rest, error
            );
            return simple_response(StatusCode::BAD_REQUEST, "Invalid playback target");
        }
    };

    let playlist_like_url = target_url.to_ascii_lowercase().contains(".m3u8");
    let hls_session = session.source_kind.to_ascii_lowercase().contains("hls");
    let mut request = state.client.get(target_url.clone());
    for (key, value) in &session.headers {
        request = request.header(key, value);
    }
    if !hls_session && !playlist_like_url && let Some(value) = incoming_headers.get(RANGE) {
        request = request.header(RANGE, value);
    }

    let upstream = match request.send().await {
        Ok(response) => response,
        Err(error) => {
            eprintln!(
                "[playback_proxy] session_id={} upstream request failed target={}: {}",
                session_id, target_url, error
            );
            return simple_response(StatusCode::BAD_GATEWAY, "Failed to load stream source");
        }
    };

    let status = upstream.status();
    let upstream_headers = upstream.headers().clone();

    if looks_like_playlist_target(&target_url, &upstream_headers) {
        let bytes = match upstream.bytes().await {
            Ok(value) => value,
            Err(error) => {
                eprintln!(
                    "[playback_proxy] session_id={} upstream body read failed target={}: {}",
                    session_id, target_url, error
                );
                return simple_response(
                    StatusCode::BAD_GATEWAY,
                    "Failed to read stream source response",
                );
            }
        };

        if !looks_like_playlist_body(&bytes) {
            eprintln!(
                "[playback_proxy] session_id={} suspected playlist but body is not m3u8 target={}",
                session_id, target_url
            );
            return build_response(
                status,
                Body::from(bytes),
                &upstream_headers,
                false,
                upstream_headers
                    .get(CONTENT_LENGTH)
                    .and_then(|v| v.to_str().ok())
                    .and_then(|v| v.parse::<u64>().ok()),
            );
        }

        let body = String::from_utf8_lossy(&bytes);
        let rewritten = rewrite_playlist(&body, &target_url, &session_id);
        eprintln!(
            "[playback_proxy] session_id={} playlist target={} status={} bytes_in={} bytes_out={}",
            session_id,
            target_url,
            status.as_u16(),
            bytes.len(),
            rewritten.len()
        );
        return build_response(
            StatusCode::OK,
            Body::from(rewritten.clone()),
            &upstream_headers,
            true,
            Some(rewritten.len() as u64),
        );
    }

    let content_length = upstream_headers
        .get(CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok());

    eprintln!(
        "[playback_proxy] session_id={} media target={} status={} content_length={:?}",
        session_id,
        target_url,
        status.as_u16(),
        content_length
    );

    let body = Body::from_stream(upstream.bytes_stream());
    build_response(
        status,
        body,
        &upstream_headers,
        false,
        content_length,
    )
}

fn resolve_target_url(
    session: &PlaybackSession,
    rest: Option<&str>,
) -> Result<String, url::ParseError> {
    let Some(rest) = rest else {
        return Ok(session.source_url.clone());
    };

    if rest.is_empty() {
        return Ok(session.source_url.clone());
    }

    if let Some(encoded) = rest.strip_prefix("u/") {
        let decoded = URL_SAFE_NO_PAD.decode(encoded).unwrap_or_default();
        let resolved = String::from_utf8(decoded).unwrap_or_default();
        let parsed = Url::parse(&resolved)?;
        return Ok(parsed.to_string());
    }

    let base = Url::parse(&session.source_url)?;
    Ok(base.join(rest)?.to_string())
}

fn looks_like_playlist_target(target_url: &str, headers: &HeaderMap) -> bool {
    let content_type = headers
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default()
        .to_ascii_lowercase();
    if content_type.contains("mpegurl") || target_url.to_ascii_lowercase().contains(".m3u8") {
        return true;
    }

    false
}

fn looks_like_playlist_body(bytes: &[u8]) -> bool {
    bytes.starts_with(b"#EXTM3U")
}

fn rewrite_playlist(body: &str, target_url: &str, session_id: &str) -> String {
    let Ok(base) = Url::parse(target_url) else {
        return body.to_string();
    };

    body.lines()
        .map(|line| {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                return line.to_string();
            }
            if trimmed.starts_with('#') {
                return rewrite_hls_tag_uri_attributes(line, &base, session_id);
            }

            let resolved = Url::parse(trimmed).or_else(|_| base.join(trimmed));
            match resolved {
                Ok(url) => {
                    let encoded = URL_SAFE_NO_PAD.encode(url.as_str());
                    format!("/play/{session_id}/u/{encoded}")
                }
                Err(_) => line.to_string(),
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn rewrite_hls_tag_uri_attributes(line: &str, base: &Url, session_id: &str) -> String {
    HLS_URI_ATTR_RE
        .replace_all(line, |captures: &regex::Captures| {
            let raw_uri = captures
                .get(1)
                .or_else(|| captures.get(2))
                .map(|m| m.as_str())
                .unwrap_or_default();

            match Url::parse(raw_uri).or_else(|_| base.join(raw_uri)) {
                Ok(url) => {
                    let encoded = URL_SAFE_NO_PAD.encode(url.as_str());
                    format!("URI=\"/play/{session_id}/u/{encoded}\"")
                }
                Err(_) => captures
                    .get(0)
                    .map(|m| m.as_str().to_string())
                    .unwrap_or_default(),
            }
        })
        .to_string()
}

fn build_response(
    status: StatusCode,
    body: Body,
    upstream_headers: &HeaderMap,
    force_playlist_content_type: bool,
    content_length: Option<u64>,
) -> Response<Body> {
    let mut response = Response::new(body);
    *response.status_mut() = status;

    let headers = response.headers_mut();
    headers.insert(ACCESS_CONTROL_ALLOW_ORIGIN, HeaderValue::from_static("*"));
    if force_playlist_content_type {
        headers.insert(
            CONTENT_TYPE,
            HeaderValue::from_static("application/vnd.apple.mpegurl"),
        );
    } else if let Some(value) = upstream_headers.get(CONTENT_TYPE) {
        headers.insert(CONTENT_TYPE, value.clone());
    }

    if !force_playlist_content_type {
        if let Some(value) = upstream_headers.get(ACCEPT_RANGES) {
            headers.insert(ACCEPT_RANGES, value.clone());
        }
        if let Some(value) = upstream_headers.get(CONTENT_RANGE) {
            headers.insert(CONTENT_RANGE, value.clone());
        }
    }
    if let Some(length) = content_length {
        let value = HeaderValue::from_str(&length.to_string())
            .unwrap_or_else(|_| HeaderValue::from_static("0"));
        headers.insert(CONTENT_LENGTH, value);
    }

    response
}

fn simple_response(status: StatusCode, message: &str) -> Response<Body> {
    build_response(
        status,
        Body::from(message.to_string()),
        &HeaderMap::new(),
        false,
        Some(message.len() as u64),
    )
}

fn random_session_id() -> String {
    let mut rng = rand::thread_rng();
    (&mut rng)
        .sample_iter(&Alphanumeric)
        .take(20)
        .map(char::from)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rewrite_playlist_proxies_segment_and_key_uris() {
        let session_id = "testsession";
        let target = "https://cdn.example.com/videos/master.m3u8";
        let input = "#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"enc.key\"\nseg-001.ts";

        let output = rewrite_playlist(input, target, session_id);

        let key_url = "https://cdn.example.com/videos/enc.key";
        let key_encoded = URL_SAFE_NO_PAD.encode(key_url);
        assert!(
            output.contains(&format!("URI=\"/play/{session_id}/u/{key_encoded}\"")),
            "expected key URI rewrite, output={output}"
        );

        let segment_url = "https://cdn.example.com/videos/seg-001.ts";
        let segment_encoded = URL_SAFE_NO_PAD.encode(segment_url);
        assert!(
            output.contains(&format!("/play/{session_id}/u/{segment_encoded}")),
            "expected segment URI rewrite, output={output}"
        );
    }
}