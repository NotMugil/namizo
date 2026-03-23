use crate::{auth, error::TvdbError, mapping::lookup_tvdb_match, models::TvdbEpisode};
use reqwest::Client;
use serde_json::Value;

const BASE_URL: &str = "https://api4.thetvdb.com/v4";
const ENGLISH_LANG: &str = "eng";
const ARTWORK_CDN_BASE: &str = "https://artworks.thetvdb.com/banners/";
const FALLBACK_SERIES_BACKGROUND_TYPE_ID: u64 = 3;

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
        match format {
            Some("MOVIE") => {
                return Err(TvdbError::Skipped("movies don't have episode lists".into()));
            }
            Some("SPECIAL") | Some("MUSIC") => {
                return Err(TvdbError::Skipped(format!("{:?} skipped", format)));
            }
            _ => {}
        }

        let tvdb_match = lookup_tvdb_match(mapping, anilist_id, format)?;
        let tvdb_id = tvdb_match.tvdb_id;
        let season_tvdb = tvdb_match.season_tvdb;
        let token = auth::get_token(&self.client, &self.api_key).await?;
        match self
            .fetch_series_episodes(tvdb_id, season_tvdb, &token)
            .await
        {
            Err(TvdbError::Http(ref e)) if e.status().map(|s| s.as_u16()) == Some(401) => {
                auth::invalidate_token().await;
                let token = auth::get_token(&self.client, &self.api_key).await?;
                self.fetch_series_episodes(tvdb_id, season_tvdb, &token)
                    .await
            }
            other => other,
        }
    }

    pub async fn get_background(
        &self,
        anilist_id: u32,
        format: Option<&str>,
        mapping: &[Value],
    ) -> Result<Option<String>, TvdbError> {
        let tvdb_match = lookup_tvdb_match(mapping, anilist_id, format)?;
        let tvdb_id = tvdb_match.tvdb_id;
        let token = auth::get_token(&self.client, &self.api_key).await?;
        match self.fetch_series_background(tvdb_id, &token).await {
            Err(TvdbError::Http(ref e)) if e.status().map(|s| s.as_u16()) == Some(401) => {
                auth::invalidate_token().await;
                let token = auth::get_token(&self.client, &self.api_key).await?;
                self.fetch_series_background(tvdb_id, &token).await
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
            Err(_) => {
                self.fetch_series_episodes_default(tvdb_id, season_tvdb, token)
                    .await?
            }
        };
        let source_episodes = filter_episodes_by_season(source_episodes, season_tvdb);
        let mut raw_episodes: Vec<RawTvdbEpisode> = Vec::with_capacity(source_episodes.len());
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
                        Err(_) => {}
                    }
                }
            }

            raw_episodes.push(mapped);
        }
        let episodes = normalize_tvdb_episode_numbers(raw_episodes, season_tvdb);
        Ok(episodes)
    }

    async fn fetch_series_background(
        &self,
        tvdb_id: u64,
        token: &str,
    ) -> Result<Option<String>, TvdbError> {
        let background_type_id = self.resolve_series_background_type_id(token).await;

        let english_artworks = self
            .fetch_series_artworks(tvdb_id, background_type_id, Some(ENGLISH_LANG), token)
            .await?;
        let fallback_artworks = self
            .fetch_series_artworks(tvdb_id, background_type_id, None, token)
            .await?;
        let combined = merge_artworks(english_artworks, fallback_artworks);

        Ok(select_best_background_url(&combined))
    }

    async fn fetch_series_episodes_default(
        &self,
        tvdb_id: u64,
        season_tvdb: Option<u32>,
        token: &str,
    ) -> Result<Vec<Value>, TvdbError> {
        let url = build_series_episodes_url(tvdb_id, None, season_tvdb);
        self.fetch_series_episodes_by_url(tvdb_id, token, &url)
            .await
    }

    async fn fetch_series_episodes_for_language(
        &self,
        tvdb_id: u64,
        season_tvdb: Option<u32>,
        token: &str,
        language: &str,
    ) -> Result<Vec<Value>, TvdbError> {
        let url = build_series_episodes_url(tvdb_id, Some(language), season_tvdb);
        self.fetch_series_episodes_by_url(tvdb_id, token, &url)
            .await
    }

    async fn fetch_series_episodes_by_url(
        &self,
        tvdb_id: u64,
        token: &str,
        url: &str,
    ) -> Result<Vec<Value>, TvdbError> {
        let raw = self.client.get(url).bearer_auth(token).send().await?;
        let response: Value = raw.json().await?;

        if response["status"].as_str() == Some("failure") {
            return Err(TvdbError::NotFound(tvdb_id));
        }

        let episodes = response["data"]["episodes"]
            .as_array()
            .ok_or_else(|| TvdbError::Parse("missing episodes array".into()))?;

        Ok(episodes.to_vec())
    }

    async fn fetch_series_artworks(
        &self,
        tvdb_id: u64,
        artwork_type_id: u64,
        language: Option<&str>,
        token: &str,
    ) -> Result<Vec<Value>, TvdbError> {
        let url = build_series_artworks_url(tvdb_id, artwork_type_id, language);
        let raw = self.client.get(&url).bearer_auth(token).send().await?;
        let status = raw.status();
        if status.as_u16() == 404 {
            return Ok(Vec::new());
        }

        let response: Value = raw.json().await?;
        if response["status"].as_str() == Some("failure") {
            return Ok(Vec::new());
        }

        Ok(extract_artworks(&response))
    }

    async fn resolve_series_background_type_id(&self, token: &str) -> u64 {
        match self.fetch_artwork_types(token).await {
            Ok(types) => {
                if let Some(id) = find_series_background_type_id(&types) {
                    return id;
                }
                FALLBACK_SERIES_BACKGROUND_TYPE_ID
            }
            Err(_) => FALLBACK_SERIES_BACKGROUND_TYPE_ID,
        }
    }

    async fn fetch_artwork_types(&self, token: &str) -> Result<Vec<Value>, TvdbError> {
        let url = format!("{}/artwork/types", BASE_URL);
        let raw = self.client.get(&url).bearer_auth(token).send().await?;
        let status = raw.status();
        if status.as_u16() == 404 {
            return Ok(Vec::new());
        }

        let response: Value = raw.json().await?;
        if response["status"].as_str() == Some("failure") {
            return Ok(Vec::new());
        }

        Ok(response["data"]
            .as_array()
            .map(|items| items.to_vec())
            .unwrap_or_default())
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
        let raw = self.client.get(&url).bearer_auth(token).send().await?;
        let status = raw.status();
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

fn build_series_artworks_url(tvdb_id: u64, artwork_type_id: u64, language: Option<&str>) -> String {
    let mut url = format!(
        "{}/series/{}/artworks?type={}",
        BASE_URL, tvdb_id, artwork_type_id
    );
    if let Some(lang) = language {
        url.push_str("&lang=");
        url.push_str(lang);
    }
    url
}

fn extract_artworks(response: &Value) -> Vec<Value> {
    if let Some(items) = response["data"].as_array() {
        return items.to_vec();
    }

    if let Some(items) = response["data"]["artworks"].as_array() {
        return items.to_vec();
    }

    Vec::new()
}

fn select_best_background_url(artworks: &[Value]) -> Option<String> {
    let no_text_ranked = artworks
        .iter()
        .filter(|artwork| !artwork_has_embedded_text(artwork))
        .filter(|artwork| is_valid_background(artwork))
        .filter_map(|artwork| {
            let image = artwork["image"].as_str()?;
            let url = normalize_artwork_url(image)?;
            Some((artwork_rank(artwork), url))
        })
        .max_by_key(|(rank, _)| *rank)
        .map(|(_, url)| url);
    if no_text_ranked.is_some() {
        return no_text_ranked;
    }

    let ranked_valid = artworks
        .iter()
        .filter(|artwork| is_valid_background(artwork))
        .filter_map(|artwork| {
            let image = artwork["image"].as_str()?;
            let url = normalize_artwork_url(image)?;
            Some((artwork_rank(artwork), url))
        })
        .max_by_key(|(rank, _)| *rank)
        .map(|(_, url)| url);

    if ranked_valid.is_some() {
        return ranked_valid;
    }

    // Fallback path when metadata is incomplete: still choose best available image.
    artworks
        .iter()
        .filter_map(|artwork| {
            let image = artwork["image"].as_str()?;
            let url = normalize_artwork_url(image)?;
            Some((artwork_rank(artwork), url))
        })
        .max_by_key(|(rank, _)| *rank)
        .map(|(_, url)| url)
}

fn is_valid_background(artwork: &Value) -> bool {
    let width = value_to_u64(&artwork["width"]).unwrap_or(0);
    let height = value_to_u64(&artwork["height"]).unwrap_or(0);
    if width < 1280 || height < 720 {
        return false;
    }
    if height > width {
        return false;
    }

    let ratio = (width as f64) / (height as f64);
    (1.6..=1.9).contains(&ratio)
}

fn artwork_rank(artwork: &Value) -> i64 {
    let score = value_to_i64(&artwork["score"]).unwrap_or(0);
    let width = value_to_u64(&artwork["width"]).unwrap_or(0);
    let height = value_to_u64(&artwork["height"]).unwrap_or(0);
    let language = artwork["language"]
        .as_str()
        .map(str::trim)
        .unwrap_or("")
        .to_ascii_lowercase();

    let lang_bonus = if language.is_empty() || language == "null" {
        150_000
    } else if language == ENGLISH_LANG || language == "en" {
        50_000
    } else {
        0
    };
    let text_bonus = match artwork_includes_text(artwork) {
        Some(true) => -120_000,
        Some(false) => 60_000,
        None => 0,
    };
    let res_bonus = if width >= 2560 && height >= 1440 {
        100_000
    } else if width >= 1920 && height >= 1080 {
        50_000
    } else if width >= 1280 && height >= 720 {
        20_000
    } else {
        0
    };

    score.saturating_mul(2) + lang_bonus + text_bonus + res_bonus
}

fn artwork_includes_text(artwork: &Value) -> Option<bool> {
    let value = &artwork["includesText"];
    if let Some(boolean) = value.as_bool() {
        return Some(boolean);
    }
    if let Some(number) = value.as_i64() {
        return Some(number != 0);
    }
    if let Some(number) = value.as_u64() {
        return Some(number != 0);
    }
    if let Some(text) = value.as_str() {
        let normalized = text.trim().to_ascii_lowercase();
        if normalized.is_empty() {
            return None;
        }
        if normalized == "true" || normalized == "1" || normalized == "yes" {
            return Some(true);
        }
        if normalized == "false" || normalized == "0" || normalized == "no" {
            return Some(false);
        }
    }
    None
}

fn artwork_has_embedded_text(artwork: &Value) -> bool {
    matches!(artwork_includes_text(artwork), Some(true))
}

fn value_to_i64(value: &Value) -> Option<i64> {
    value
        .as_i64()
        .or_else(|| value.as_u64().map(|number| number as i64))
        .or_else(|| value.as_str().and_then(|number| number.parse::<i64>().ok()))
}

fn value_to_u64(value: &Value) -> Option<u64> {
    value
        .as_u64()
        .or_else(|| {
            value
                .as_i64()
                .filter(|number| *number >= 0)
                .map(|number| number as u64)
        })
        .or_else(|| value.as_str().and_then(|number| number.parse::<u64>().ok()))
}

fn normalize_artwork_url(image: &str) -> Option<String> {
    let trimmed = image.trim();
    if trimmed.is_empty() {
        return None;
    }

    if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
        return Some(trimmed.to_string());
    }

    if trimmed.starts_with("/banners/") {
        return Some(format!("https://artworks.thetvdb.com{}", trimmed));
    }

    if trimmed.starts_with("banners/") {
        return Some(format!("https://artworks.thetvdb.com/{}", trimmed));
    }

    Some(format!(
        "{}{}",
        ARTWORK_CDN_BASE,
        trimmed.trim_start_matches('/')
    ))
}

fn merge_artworks(primary: Vec<Value>, secondary: Vec<Value>) -> Vec<Value> {
    let mut out = Vec::with_capacity(primary.len() + secondary.len());
    let mut seen = std::collections::HashSet::new();

    for artwork in primary.into_iter().chain(secondary.into_iter()) {
        let key = artwork["id"]
            .as_u64()
            .map(|id| format!("id:{id}"))
            .or_else(|| {
                artwork["image"]
                    .as_str()
                    .map(|image| format!("img:{}", image.trim()))
            });
        if let Some(key) = key {
            if !seen.insert(key) {
                continue;
            }
        }
        out.push(artwork);
    }

    out
}

fn find_series_background_type_id(types: &[Value]) -> Option<u64> {
    let by_slug = types.iter().find_map(|entry| {
        let slug = entry["slug"]
            .as_str()
            .or_else(|| entry["name"].as_str())
            .unwrap_or("")
            .to_ascii_lowercase();
        let id = entry["id"].as_u64()?;
        if slug == "series-background" || slug == "series background" {
            Some(id)
        } else {
            None
        }
    });
    if by_slug.is_some() {
        return by_slug;
    }

    types.iter().find_map(|entry| {
        let id = entry["id"].as_u64()?;
        let name = entry["name"].as_str().unwrap_or("").to_ascii_lowercase();
        let slug = entry["slug"].as_str().unwrap_or("").to_ascii_lowercase();
        let record_type = entry["recordType"]
            .as_str()
            .or_else(|| entry["record_type"].as_str())
            .unwrap_or("")
            .to_ascii_lowercase();

        let is_background = name.contains("background") || slug.contains("background");
        let is_series =
            record_type.contains("series") || name.contains("series") || slug.contains("series");
        if is_background && is_series {
            Some(id)
        } else {
            None
        }
    })
}

fn filter_episodes_by_season(source_episodes: Vec<Value>, season_tvdb: Option<u32>) -> Vec<Value> {
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
    filtered
}

fn map_episode(ep: &Value) -> Option<RawTvdbEpisode> {
    let number_in_season = ep["number"].as_u64()? as u32;
    if number_in_season == 0 {
        return None;
    }

    let season_number = ep["seasonNumber"].as_u64().map(|value| value as u32);
    if season_number == Some(0) {
        // TVDB season 0 entries are specials/extras and should not be mixed into main episodes.
        return None;
    }

    let absolute_number = ep["numberAbsolute"]
        .as_u64()
        .or_else(|| ep["absoluteNumber"].as_u64())
        .or_else(|| ep["absNumber"].as_u64())
        .map(|value| value as u32)
        .filter(|value| *value > 0);

    let title = ep["name"]
        .as_str()
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string());
    let thumbnail = ep["image"].as_str().filter(|s| !s.is_empty()).map(|s| {
        if s.starts_with("http") {
            s.to_string()
        } else {
            format!("https://artworks.thetvdb.com{}", s)
        }
    });
    Some(RawTvdbEpisode {
        number_in_season,
        season_number,
        absolute_number,
        title,
        thumbnail,
    })
}

fn normalize_tvdb_episode_numbers(
    mut source: Vec<RawTvdbEpisode>,
    season_tvdb: Option<u32>,
) -> Vec<TvdbEpisode> {
    if source.is_empty() {
        return Vec::new();
    }

    source.sort_by(|a, b| {
        let season_a = a.season_number.unwrap_or(1);
        let season_b = b.season_number.unwrap_or(1);
        season_a
            .cmp(&season_b)
            .then_with(|| a.number_in_season.cmp(&b.number_in_season))
    });

    if season_tvdb.is_some() {
        return source
            .into_iter()
            .enumerate()
            .map(|(index, ep)| TvdbEpisode {
                number: (index as u32) + 1,
                title: ep.title,
                thumbnail: ep.thumbnail,
            })
            .collect();
    }

    let can_use_absolute_numbers = source.iter().all(|ep| ep.absolute_number.is_some())
        && source
            .windows(2)
            .all(|pair| pair[0].absolute_number < pair[1].absolute_number);

    if can_use_absolute_numbers {
        return source
            .into_iter()
            .filter_map(|ep| {
                Some(TvdbEpisode {
                    number: ep.absolute_number?,
                    title: ep.title,
                    thumbnail: ep.thumbnail,
                })
            })
            .collect();
    }

    let first_known_season = source.iter().find_map(|ep| ep.season_number);
    let has_multiple_seasons = first_known_season
        .map(|first| {
            source
                .iter()
                .filter_map(|ep| ep.season_number)
                .any(|season| season != first)
        })
        .unwrap_or(false);

    if has_multiple_seasons {
        return source
            .into_iter()
            .enumerate()
            .map(|(index, ep)| TvdbEpisode {
                number: (index as u32) + 1,
                title: ep.title,
                thumbnail: ep.thumbnail,
            })
            .collect();
    }

    source
        .into_iter()
        .map(|ep| TvdbEpisode {
            number: ep.number_in_season,
            title: ep.title,
            thumbnail: ep.thumbnail,
        })
        .collect()
}

#[derive(Debug, Clone)]
struct RawTvdbEpisode {
    number_in_season: u32,
    season_number: Option<u32>,
    absolute_number: Option<u32>,
    title: Option<String>,
    thumbnail: Option<String>,
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn normalize_artwork_url_handles_relative_and_absolute() {
        assert_eq!(
            normalize_artwork_url("/banners/v4/fanart/a.jpg"),
            Some("https://artworks.thetvdb.com/banners/v4/fanart/a.jpg".to_string())
        );
        assert_eq!(
            normalize_artwork_url("v4/banners/backgrounds/c.jpg"),
            Some("https://artworks.thetvdb.com/banners/v4/banners/backgrounds/c.jpg".to_string())
        );
        assert_eq!(
            normalize_artwork_url("https://artworks.thetvdb.com/banners/v4/fanart/b.jpg"),
            Some("https://artworks.thetvdb.com/banners/v4/fanart/b.jpg".to_string())
        );
    }

    #[test]
    fn select_best_background_prefers_higher_score() {
        let artworks = vec![
            json!({
                "image": "/banners/posters/poster.jpg",
                "score": 100,
                "width": 1920,
                "height": 1080,
                "language": "eng",
                "includesText": false
            }),
            json!({
                "image": "/banners/fanart/bg.jpg",
                "score": 420,
                "width": 1920,
                "height": 1080,
                "language": "eng",
                "includesText": false
            }),
        ];

        assert_eq!(
            select_best_background_url(&artworks),
            Some("https://artworks.thetvdb.com/banners/fanart/bg.jpg".to_string())
        );
    }

    #[test]
    fn select_best_background_prefers_no_language_when_scores_are_close() {
        let artworks = vec![
            json!({
                "image": "/banners/fanart/with-text.jpg",
                "score": 1_000_000,
                "width": 1920,
                "height": 1080,
                "language": "eng",
                "includesText": true
            }),
            json!({
                "image": "/banners/fanart/no-text.jpg",
                "score": 900_000,
                "width": 1920,
                "height": 1080,
                "language": "",
                "includesText": false
            }),
        ];

        assert_eq!(
            select_best_background_url(&artworks),
            Some("https://artworks.thetvdb.com/banners/fanart/no-text.jpg".to_string())
        );
    }

    #[test]
    fn select_best_background_filters_low_resolution_first() {
        let artworks = vec![
            json!({
                "image": "/banners/fanart/low.jpg",
                "score": 999999,
                "width": 960,
                "height": 540,
                "language": "",
                "includesText": false
            }),
            json!({
                "image": "/banners/fanart/hd.jpg",
                "score": 1000,
                "width": 1920,
                "height": 1080,
                "language": "eng",
                "includesText": false
            }),
        ];

        assert_eq!(
            select_best_background_url(&artworks),
            Some("https://artworks.thetvdb.com/banners/fanart/hd.jpg".to_string())
        );
    }

    #[test]
    fn find_series_background_type_id_uses_slug_or_name() {
        let types = vec![
            json!({ "id": 2, "name": "Series Poster", "slug": "series-poster", "recordType": "series" }),
            json!({ "id": 3, "name": "Series Background", "slug": "series-background", "recordType": "series" }),
        ];
        assert_eq!(find_series_background_type_id(&types), Some(3));
    }

    #[test]
    fn select_best_background_avoids_explicit_text_even_with_higher_score() {
        let artworks = vec![
            json!({
                "id": 1,
                "image": "/banners/fanart/text.jpg",
                "score": 3_000_000,
                "width": 1920,
                "height": 1080,
                "language": "eng",
                "includesText": true
            }),
            json!({
                "id": 2,
                "image": "/banners/fanart/clean.jpg",
                "score": 300_000,
                "width": 1920,
                "height": 1080,
                "language": "",
                "includesText": false
            }),
        ];

        assert_eq!(
            select_best_background_url(&artworks),
            Some("https://artworks.thetvdb.com/banners/fanart/clean.jpg".to_string())
        );
    }

    #[test]
    fn merge_artworks_deduplicates_by_id_or_image() {
        let merged = merge_artworks(
            vec![
                json!({"id": 7, "image": "/a.jpg"}),
                json!({"image": "/b.jpg"}),
            ],
            vec![
                json!({"id": 7, "image": "/a2.jpg"}),
                json!({"image": "/b.jpg"}),
                json!({"id": 8, "image": "/c.jpg"}),
            ],
        );

        assert_eq!(merged.len(), 3);
    }
}