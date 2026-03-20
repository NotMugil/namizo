use reqwest::Client;
use serde_json::Value;
use crate::{
    auth,
    error::TvdbError,
    mapping::lookup_tvdb_match,
    models::TvdbEpisode,
};

const BASE_URL: &str = "https://api4.thetvdb.com/v4";
const ENGLISH_LANG: &str = "eng";

pub struct TvdbClient {
    pub client: Client,
    api_key: String,
}

impl TvdbClient {
    pub fn new(api_key: impl Into<String>) -> Self {
        Self {
            client: Client::new(),
            api_key: api_key.into(),
        }
    }

    pub async fn get_episodes(
        &self,
        anilist_id: u32,
        format: Option<&str>,
        mapping: &[Value],
    ) -> Result<Vec<TvdbEpisode>, TvdbError> {
        println!(
            "[TVDB][client] get_episodes anilist_id={} format={:?}",
            anilist_id,
            format
        );

        match format {
            Some("MOVIE") => {
                println!("[TVDB][client] skip format=MOVIE anilist_id={}", anilist_id);
                return Err(TvdbError::Skipped("movies don't have episode lists".into()))
            }
            Some("SPECIAL") | Some("MUSIC") => {
                println!("[TVDB][client] skip format={:?} anilist_id={}", format, anilist_id);
                return Err(TvdbError::Skipped(format!("{:?} skipped", format)))
            }
            _ => {}
        }

        let tvdb_match = lookup_tvdb_match(mapping, anilist_id, format)?;
        let tvdb_id = tvdb_match.tvdb_id;
        let season_tvdb = tvdb_match.season_tvdb;
        println!(
            "[TVDB][client] mapping anilist_id={} -> tvdb_id={} season_tvdb={:?}",
            anilist_id,
            tvdb_id,
            season_tvdb
        );
        let token = auth::get_token(&self.client, &self.api_key).await?;
        println!(
            "[TVDB][client] token_ready anilist_id={} token_len={}",
            anilist_id,
            token.len()
        );

        match self.fetch_series_episodes(tvdb_id, season_tvdb, &token).await {
            Err(TvdbError::Http(ref e)) if e.status().map(|s| s.as_u16()) == Some(401) => {
                eprintln!(
                    "[TVDB][client] 401 for tvdb_id={} -> invalidating token and retrying",
                    tvdb_id
                );
                auth::invalidate_token().await;
                let token = auth::get_token(&self.client, &self.api_key).await?;
                self.fetch_series_episodes(tvdb_id, season_tvdb, &token).await
            }
            other => other,
        }
    }

    async fn fetch_series_episodes(
        &self,
        tvdb_id: u64,
        season_tvdb: Option<u32>,
        token: &str,
    ) -> Result<Vec<TvdbEpisode>, TvdbError> {
        let source_episodes = match self
            .fetch_series_episodes_for_language(tvdb_id, season_tvdb, token, ENGLISH_LANG)
            .await
        {
            Ok(episodes) => episodes,
            Err(err) => {
                eprintln!(
                    "[TVDB][client] english endpoint failed tvdb_id={} season_tvdb={:?} err={} -> falling back to default language",
                    tvdb_id,
                    season_tvdb,
                    err
                );
                self.fetch_series_episodes_default(tvdb_id, season_tvdb, token).await?
            }
        };
        let source_episodes = filter_episodes_by_season(source_episodes, season_tvdb);
        println!(
            "[TVDB][client] source_episodes_count tvdb_id={} season_tvdb={:?} count={}",
            tvdb_id,
            season_tvdb,
            source_episodes.len()
        );

        let mut episodes: Vec<TvdbEpisode> = Vec::with_capacity(source_episodes.len());
        for episode in source_episodes {
            let Some(mut mapped) = map_episode(&episode) else {
                continue;
            };

            if needs_english_override(mapped.title.as_deref()) {
                if let Some(episode_id) = episode["id"].as_u64() {
                    match self
                        .fetch_episode_translation_name(episode_id, token, ENGLISH_LANG)
                        .await
                    {
                        Ok(Some(english_title)) => {
                            mapped.title = Some(english_title);
                        }
                        Ok(None) => {}
                        Err(err) => {
                            eprintln!(
                                "[TVDB][client] episode translation failed tvdb_episode_id={} err={}",
                                episode_id,
                                err
                            );
                        }
                    }
                }
            }

            episodes.push(mapped);
        }
        println!(
            "[TVDB][client] mapped_episodes_count tvdb_id={} count={}",
            tvdb_id,
            episodes.len()
        );

        Ok(episodes)
    }

    async fn fetch_series_episodes_default(
        &self,
        tvdb_id: u64,
        season_tvdb: Option<u32>,
        token: &str,
    ) -> Result<Vec<Value>, TvdbError> {
        let url = build_series_episodes_url(tvdb_id, None, season_tvdb);
        self.fetch_series_episodes_by_url(tvdb_id, token, &url).await
    }

    async fn fetch_series_episodes_for_language(
        &self,
        tvdb_id: u64,
        season_tvdb: Option<u32>,
        token: &str,
        language: &str,
    ) -> Result<Vec<Value>, TvdbError> {
        let url = build_series_episodes_url(tvdb_id, Some(language), season_tvdb);
        self.fetch_series_episodes_by_url(tvdb_id, token, &url).await
    }

    async fn fetch_series_episodes_by_url(
        &self,
        tvdb_id: u64,
        token: &str,
        url: &str,
    ) -> Result<Vec<Value>, TvdbError> {
        println!("[TVDB][client] fetch url={}", url);

        let raw = self
            .client
            .get(url)
            .bearer_auth(token)
            .send()
            .await?;
        let status = raw.status();
        println!("[TVDB][client] fetch status={} tvdb_id={}", status, tvdb_id);
        let response: Value = raw.json().await?;

        if response["status"].as_str() == Some("failure") {
            eprintln!(
                "[TVDB][client] response failure tvdb_id={} message={:?}",
                tvdb_id,
                response["message"].as_str()
            );
            return Err(TvdbError::NotFound(tvdb_id));
        }

        let episodes = response["data"]["episodes"].as_array().ok_or_else(|| {
            eprintln!(
                "[TVDB][client] missing episodes array tvdb_id={} response_keys={:?}",
                tvdb_id,
                response["data"]
                    .as_object()
                    .map(|o| o.keys().cloned().collect::<Vec<_>>())
            );
            TvdbError::Parse("missing episodes array".into())
        })?;

        Ok(episodes.to_vec())
    }

    async fn fetch_episode_translation_name(
        &self,
        episode_id: u64,
        token: &str,
        language: &str,
    ) -> Result<Option<String>, TvdbError> {
        let url = format!(
            "{}/episodes/{}/translations/{}",
            BASE_URL, episode_id, language
        );
        println!(
            "[TVDB][client] fetch episode translation url={} episode_id={}",
            url,
            episode_id
        );

        let raw = self
            .client
            .get(&url)
            .bearer_auth(token)
            .send()
            .await?;
        let status = raw.status();
        println!(
            "[TVDB][client] episode translation status={} episode_id={}",
            status,
            episode_id
        );

        if status.as_u16() == 404 {
            return Ok(None);
        }

        let response: Value = raw.json().await?;
        if response["status"].as_str() == Some("failure") {
            return Ok(None);
        }

        let title = response["data"]["name"]
            .as_str()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(ToString::to_string);

        Ok(title)
    }
}

fn build_series_episodes_url(
    tvdb_id: u64,
    language: Option<&str>,
    season_tvdb: Option<u32>,
) -> String {
    let mut url = match language {
        Some(lang) => format!(
            "{}/series/{}/episodes/default/{}?page=0",
            BASE_URL, tvdb_id, lang
        ),
        None => format!("{}/series/{}/episodes/default?page=0", BASE_URL, tvdb_id),
    };

    if let Some(season) = season_tvdb {
        url.push_str("&season=");
        url.push_str(&season.to_string());
    }

    url
}

fn filter_episodes_by_season(
    source_episodes: Vec<Value>,
    season_tvdb: Option<u32>,
) -> Vec<Value> {
    let Some(season) = season_tvdb else {
        return source_episodes;
    };

    let filtered: Vec<Value> = source_episodes
        .into_iter()
        .filter(|ep| {
            ep["seasonNumber"]
                .as_u64()
                .map(|value| value as u32 == season)
                .unwrap_or(true)
        })
        .collect();

    println!(
        "[TVDB][client] season_filter season_tvdb={} -> kept={}",
        season,
        filtered.len()
    );
    filtered
}

fn map_episode(ep: &Value) -> Option<TvdbEpisode> {
    let number = ep["number"].as_u64()? as u32;
    let title = ep["name"]
        .as_str()
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string());
    let thumbnail = ep["image"]
        .as_str()
        .filter(|s| !s.is_empty())
        .map(|s| {
            if s.starts_with("http") { s.to_string() }
            else { format!("https://artworks.thetvdb.com{}", s) }
        });
    Some(TvdbEpisode { number, title, thumbnail })
}

fn needs_english_override(title: Option<&str>) -> bool {
    let Some(value) = title.map(str::trim).filter(|s| !s.is_empty()) else {
        return true;
    };

    let has_ascii_alpha = value.chars().any(|c| c.is_ascii_alphabetic());
    let has_cjk_or_hangul = value.chars().any(is_cjk_or_hangul);
    has_cjk_or_hangul || !has_ascii_alpha
}

fn is_cjk_or_hangul(c: char) -> bool {
    ('\u{3040}'..='\u{30ff}').contains(&c)
        || ('\u{3400}'..='\u{4dbf}').contains(&c)
        || ('\u{4e00}'..='\u{9fff}').contains(&c)
        || ('\u{f900}'..='\u{faff}').contains(&c)
        || ('\u{ac00}'..='\u{d7af}').contains(&c)
}