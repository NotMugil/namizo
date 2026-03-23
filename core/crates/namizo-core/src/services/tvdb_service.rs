use chrono::Utc;
use serde_json::Value;
use std::path::Path;
use std::sync::{Arc, Mutex};
use store::{Database, EpisodeCache};
use tvdb::mapping::load_mapping;
use tvdb::{TvdbClient, TvdbEpisode, TvdbError};

const TVDB_EPISODE_CACHE_KEY_OFFSET: u32 = 1_000_000_000;
const TVDB_BACKGROUND_CACHE_KEY_OFFSET: u32 = 1_300_000_000;
const TVDB_BACKGROUND_MISS_TTL_SECONDS: i64 = 6 * 60 * 60;

pub struct TvdbService {
    client: TvdbClient,
    db: Mutex<Database>,
    mapping: Arc<Vec<Value>>,
}

impl TvdbService {
    pub async fn new(
        api_key: impl Into<String>,
        db_path: &Path,
        app_data_dir: &Path,
        bundled_mapping_path: &Path,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let client = TvdbClient::new(api_key);

        // load + auto-update mapping at startup
        let mapping = load_mapping(app_data_dir, bundled_mapping_path, &client.client).await?;
        let db = Database::open(db_path)?;
        db.migrate()?;

        Ok(Self {
            client,
            db: Mutex::new(db),
            mapping: Arc::new(mapping),
        })
    }

    pub async fn get_episodes(
        &self,
        anilist_id: u32,
        format: Option<&str>,
    ) -> Result<Vec<TvdbEpisode>, String> {
        let cache_key = anilist_id.saturating_add(TVDB_EPISODE_CACHE_KEY_OFFSET);
        // check cache first
        {
            let db = self.db.lock().unwrap();
            let cache = EpisodeCache::new(&db);
            if let Ok(Some(cached)) = cache.get::<Vec<TvdbEpisode>>(cache_key) {
                if !has_non_english_titles(&cached) {
                    return Ok(cached);
                }
            }
        }

        // fetch from TVDB using in-memory mapping
        let episodes = self
            .client
            .get_episodes(anilist_id, format, &self.mapping)
            .await
            .map_err(|e| match e {
                TvdbError::Skipped(msg) => format!("skipped:{}", msg),
                TvdbError::MappingNotFound(id) => format!("no_mapping:{}", id),
                other => other.to_string(),
            })?;
        // save to cache
        {
            let db = self.db.lock().unwrap();
            let cache = EpisodeCache::new(&db);
            let _ = cache.set(cache_key, &episodes);
        }

        Ok(episodes)
    }

    pub async fn get_background(
        &self,
        anilist_id: u32,
        format: Option<&str>,
    ) -> Result<Option<String>, String> {
        let cache_key = anilist_id.saturating_add(TVDB_BACKGROUND_CACHE_KEY_OFFSET);
        let now = Utc::now().timestamp();

        {
            let db = self.db.lock().unwrap();
            let cache = EpisodeCache::new(&db);
            if let Ok(Some(cached)) = cache.get::<Value>(cache_key) {
                if let Some(url) = cached["url"].as_str().map(|value| value.to_string()) {
                    return Ok(Some(url));
                }

                if cached["missing_until"].as_i64().unwrap_or(0) > now {
                    return Ok(None);
                }
            }
        }

        let background = match self
            .client
            .get_background(anilist_id, format, &self.mapping)
            .await
        {
            Ok(url) => url,
            Err(TvdbError::Skipped(_) | TvdbError::MappingNotFound(_) | TvdbError::NotFound(_)) => {
                None
            }
            Err(_) => None,
        };

        let cache_payload = if let Some(url) = &background {
            serde_json::json!({
                "url": url,
                "missing_until": Value::Null
            })
        } else {
            serde_json::json!({
                "url": Value::Null,
                "missing_until": now + TVDB_BACKGROUND_MISS_TTL_SECONDS
            })
        };

        {
            let db = self.db.lock().unwrap();
            let cache = EpisodeCache::new(&db);
            let _ = cache.set(cache_key, &cache_payload);
        }

        Ok(background)
    }
}

fn has_non_english_titles(episodes: &[TvdbEpisode]) -> bool {
    episodes
        .iter()
        .filter_map(|ep| ep.title.as_deref())
        .any(contains_cjk_or_hangul)
}

fn contains_cjk_or_hangul(value: &str) -> bool {
    value.chars().any(|c| {
        ('\u{3040}'..='\u{30ff}').contains(&c)
            || ('\u{3400}'..='\u{4dbf}').contains(&c)
            || ('\u{4e00}'..='\u{9fff}').contains(&c)
            || ('\u{f900}'..='\u{faff}').contains(&c)
            || ('\u{ac00}'..='\u{d7af}').contains(&c)
    })
}