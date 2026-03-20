use std::path::Path;
use std::sync::{Arc, Mutex};
use serde_json::Value;
use store::{Database, EpisodeCache};
use tvdb::{TvdbClient, TvdbEpisode, TvdbError};
use tvdb::mapping::load_mapping;

const TVDB_CACHE_KEY_OFFSET_V2: u32 = 1_000_000_000;

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
        println!(
            "[TVDB][service] initialized mapping_entries={} db_path={}",
            mapping.len(),
            db_path.display()
        );

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
        let cache_key = anilist_id.saturating_add(TVDB_CACHE_KEY_OFFSET_V2);
        println!(
            "[TVDB][service] request anilist_id={} format={:?}",
            anilist_id,
            format
        );

        // check cache first
        {
            let db = self.db.lock().unwrap();
            let cache = EpisodeCache::new(&db);
            if let Ok(Some(cached)) = cache.get::<Vec<TvdbEpisode>>(cache_key) {
                println!(
                    "[TVDB][service] cache_hit anilist_id={} cache_key={} episodes={}",
                    anilist_id,
                    cache_key,
                    cached.len()
                );
                if !has_non_english_titles(&cached) {
                    return Ok(cached);
                }
                println!(
                    "[TVDB][service] cache_refresh_required anilist_id={} cache_key={} reason=non_english_titles",
                    anilist_id,
                    cache_key
                );
            }
            println!(
                "[TVDB][service] cache_miss anilist_id={} cache_key={}",
                anilist_id,
                cache_key
            );
        }

        // fetch from TVDB using in-memory mapping
        let episodes = self.client
            .get_episodes(anilist_id, format, &self.mapping)
            .await
            .map_err(|e| match e {
                TvdbError::Skipped(msg) => format!("skipped:{}", msg),
                TvdbError::MappingNotFound(id) => format!("no_mapping:{}", id),
                other => other.to_string(),
            })?;
        println!(
            "[TVDB][service] fetched anilist_id={} episodes={}",
            anilist_id,
            episodes.len()
        );

        // save to cache
        {
            let db = self.db.lock().unwrap();
            let cache = EpisodeCache::new(&db);
            let _ = cache.set(cache_key, &episodes);
            println!(
                "[TVDB][service] cache_set anilist_id={} cache_key={} episodes={}",
                anilist_id,
                cache_key,
                episodes.len()
            );
        }

        Ok(episodes)
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