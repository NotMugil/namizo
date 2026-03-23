use std::collections::HashMap;
use std::future::Future;
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use anilist::AnilistClient;
use anilist::queries::{by_genre, details, discover, popular, search, top_rated, trending};
use domain::{AnimeDetails, AnimeSummary, DiscoverFilters, DiscoverPage};
use futures::future::join_all;
use store::{AnimeDetailsCache, CacheState, Database, StoreError};

const HOME_CACHE_TTL: Duration = Duration::from_secs(30 * 60);
const GENRE_PER_PAGE: u8 = 20;

#[derive(Hash, Eq, PartialEq)]
enum HomeCacheKey {
    Trending(u8),
    Popular(u8),
    TopRated(u8),
    Genre { genre: String, per_page: u8 },
}

struct HomeCacheEntry {
    data: Vec<AnimeSummary>,
    cached_at: Instant,
}

pub struct AnimeService {
    client: Arc<AnilistClient>,
    home_cache: Mutex<HashMap<HomeCacheKey, HomeCacheEntry>>,
    db: Mutex<Database>,
}

impl AnimeService {
    pub fn new(db_path: &Path) -> Result<Self, StoreError> {
        let db = Database::open(db_path)?;
        db.migrate()?;

        Ok(Self {
            client: Arc::new(AnilistClient::new()),
            home_cache: Mutex::new(HashMap::new()),
            db: Mutex::new(db),
        })
    }

    pub async fn trending(&self, per_page: u8) -> Result<Vec<AnimeSummary>, String> {
        self.fetch_home_row(HomeCacheKey::Trending(per_page), move |client| async move {
            trending::fetch_trending(&client, per_page)
                .await
                .map_err(|e| e.to_string())
        })
        .await
    }

    pub async fn popular(&self, per_page: u8) -> Result<Vec<AnimeSummary>, String> {
        self.fetch_home_row(HomeCacheKey::Popular(per_page), move |client| async move {
            popular::fetch_popular(&client, per_page)
                .await
                .map_err(|e| e.to_string())
        })
        .await
    }

    pub async fn top_rated(&self, per_page: u8) -> Result<Vec<AnimeSummary>, String> {
        self.fetch_home_row(HomeCacheKey::TopRated(per_page), move |client| async move {
            top_rated::fetch_top_rated(&client, per_page)
                .await
                .map_err(|e| e.to_string())
        })
        .await
    }

    pub async fn search(&self, query: &str, per_page: u8) -> Result<Vec<AnimeSummary>, String> {
        let normalized = query.trim();
        if normalized.is_empty() {
            return Ok(Vec::new());
        }

        search::fetch_search(&self.client, normalized, per_page)
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn discover(
        &self,
        filters: DiscoverFilters,
        page: u32,
        per_page: u8,
    ) -> Result<DiscoverPage, String> {
        discover::fetch_discover(&self.client, &filters, page, per_page)
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn genres_batch(
        &self,
        genres: Vec<String>,
    ) -> Result<HashMap<String, Vec<AnimeSummary>>, String> {
        let mut rows: HashMap<String, Vec<AnimeSummary>> = HashMap::new();
        let mut misses: Vec<String> = Vec::new();

        for genre in genres {
            let cache_key = HomeCacheKey::genre(&genre, GENRE_PER_PAGE);
            if let Some(cached) = self.get_home_cache(&cache_key) {
                rows.insert(genre, cached);
            } else {
                misses.push(genre);
            }
        }

        let futures: Vec<_> = misses
            .into_iter()
            .map(|genre| {
                let client = Arc::clone(&self.client);
                async move {
                    let results = by_genre::fetch_by_genre(&client, &genre, GENRE_PER_PAGE)
                        .await
                        .map_err(|e| e.to_string())?;
                    Ok::<(String, Vec<AnimeSummary>), String>((genre, results))
                }
            })
            .collect();

        let fetched = join_all(futures)
            .await
            .into_iter()
            .collect::<Result<Vec<(String, Vec<AnimeSummary>)>, String>>()?;

        for (genre, results) in fetched {
            self.set_home_cache(HomeCacheKey::genre(&genre, GENRE_PER_PAGE), results.clone());
            rows.insert(genre, results);
        }

        Ok(rows)
    }

    pub async fn details(&self, id: u32) -> Result<AnimeDetails, String> {
        let cache_state = {
            let db = self.db.lock().unwrap();
            let cache = AnimeDetailsCache::new(&db);
            cache.get::<AnimeDetails>(id).map_err(|e| e.to_string())?
        };

        let stale = match cache_state {
            CacheState::Fresh(cached) => {
                if is_valid_cached_details(&cached) {
                    return Ok(cached);
                }

                eprintln!(
                    "[ANIME][service] invalid_fresh_cache id={} reason=episodes_shape_mismatch; evicting",
                    id
                );
                self.evict_details_cache(id);
                None
            }
            CacheState::Stale(cached) => {
                if is_valid_cached_details(&cached) {
                    Some(cached)
                } else {
                    eprintln!(
                        "[ANIME][service] invalid_stale_cache id={} reason=episodes_shape_mismatch; evicting",
                        id
                    );
                    self.evict_details_cache(id);
                    None
                }
            }
            CacheState::Miss => None,
        };

        match details::fetch_details(&self.client, id).await {
            Ok(fresh) => {
                let save_result = {
                    let db = self.db.lock().unwrap();
                    let cache = AnimeDetailsCache::new(&db);
                    cache.set(id, &fresh)
                };

                if let Err(error) = save_result {
                    eprintln!(
                        "[ANIME][service] failed to persist anime details cache id={} err={}",
                        id, error
                    );
                }

                Ok(fresh)
            }
            Err(error) => match stale {
                Some(cached) => Ok(cached),
                None => Err(error.to_string()),
            },
        }
    }

    async fn fetch_home_row<F, Fut>(
        &self,
        key: HomeCacheKey,
        fetcher: F,
    ) -> Result<Vec<AnimeSummary>, String>
    where
        F: FnOnce(Arc<AnilistClient>) -> Fut,
        Fut: Future<Output = Result<Vec<AnimeSummary>, String>>,
    {
        if let Some(cached) = self.get_home_cache(&key) {
            return Ok(cached);
        }

        let fresh = fetcher(Arc::clone(&self.client)).await?;
        self.set_home_cache(key, fresh.clone());
        Ok(fresh)
    }

    fn get_home_cache(&self, key: &HomeCacheKey) -> Option<Vec<AnimeSummary>> {
        let mut cache = self.home_cache.lock().unwrap();
        if let Some(entry) = cache.get(key) {
            if entry.cached_at.elapsed() <= HOME_CACHE_TTL {
                return Some(entry.data.clone());
            }
        }

        cache.remove(key);
        None
    }

    fn set_home_cache(&self, key: HomeCacheKey, data: Vec<AnimeSummary>) {
        let mut cache = self.home_cache.lock().unwrap();
        cache.insert(
            key,
            HomeCacheEntry {
                data,
                cached_at: Instant::now(),
            },
        );
    }

    fn evict_details_cache(&self, id: u32) {
        let db = self.db.lock().unwrap();
        let cache = AnimeDetailsCache::new(&db);
        if let Err(error) = cache.delete(id) {
            eprintln!(
                "[ANIME][service] failed_to_evict_details_cache id={} err={}",
                id, error
            );
        }
    }
}

impl HomeCacheKey {
    fn genre(value: &str, per_page: u8) -> Self {
        Self::Genre {
            genre: normalize_genre(value),
            per_page,
        }
    }
}

fn normalize_genre(value: &str) -> String {
    value.trim().to_lowercase()
}

fn is_valid_cached_details(details: &AnimeDetails) -> bool {
    if let Some(count) = details.episode_count {
        if details.episodes.len() != count as usize {
            return false;
        }
    }

    for (index, episode) in details.episodes.iter().enumerate() {
        let expected = (index as u32) + 1;
        if episode.number != expected {
            return false;
        }
    }

    true
}