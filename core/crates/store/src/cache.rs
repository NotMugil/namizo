use chrono::Utc;
use serde::{Deserialize, Serialize};

use crate::{db::Database, error::StoreError};

const EPISODE_TTL_SECONDS: i64 = 7 * 24 * 60 * 60; // 7 days
const ANIME_DETAILS_TTL_SECONDS: i64 = 12 * 60 * 60; // 12 hours

pub enum CacheState<T> {
    Fresh(T),
    Stale(T),
    Miss,
}

pub struct EpisodeCache<'a> {
    db: &'a Database,
}

impl<'a> EpisodeCache<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self { db }
    }

    pub fn get<T: for<'de> Deserialize<'de>>(
        &self,
        anilist_id: u32,
    ) -> Result<Option<T>, StoreError> {
        let now = Utc::now().timestamp();
        let result = self.db.conn.query_row(
            "SELECT data, cached_at FROM tvdb_episode_cache WHERE anilist_id = ?1",
            [anilist_id],
            |row| {
                let data: String = row.get(0)?;
                let cached_at: i64 = row.get(1)?;
                Ok((data, cached_at))
            },
        );

        match result {
            Ok((data, cached_at)) => {
                if now - cached_at > EPISODE_TTL_SECONDS {
                    // stale entry is removed to preserve current TVDB cache semantics
                    self.db.conn.execute(
                        "DELETE FROM tvdb_episode_cache WHERE anilist_id = ?1",
                        [anilist_id],
                    )?;
                    return Ok(None);
                }
                let parsed = serde_json::from_str(&data)?;
                Ok(Some(parsed))
            }
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(StoreError::Db(e)),
        }
    }

    pub fn set<T: Serialize>(&self, anilist_id: u32, data: &T) -> Result<(), StoreError> {
        let now = Utc::now().timestamp();
        let json = serde_json::to_string(data)?;
        self.db.conn.execute(
            "INSERT OR REPLACE INTO tvdb_episode_cache (anilist_id, data, cached_at)
             VALUES (?1, ?2, ?3)",
            rusqlite::params![anilist_id, json, now],
        )?;
        Ok(())
    }
}

pub struct AnimeDetailsCache<'a> {
    db: &'a Database,
}

impl<'a> AnimeDetailsCache<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self { db }
    }

    pub fn get<T: for<'de> Deserialize<'de>>(
        &self,
        anilist_id: u32,
    ) -> Result<CacheState<T>, StoreError> {
        let now = Utc::now().timestamp();
        let result = self.db.conn.query_row(
            "SELECT data, cached_at FROM anime_details_cache WHERE anilist_id = ?1",
            [anilist_id],
            |row| {
                let data: String = row.get(0)?;
                let cached_at: i64 = row.get(1)?;
                Ok((data, cached_at))
            },
        );

        match result {
            Ok((data, cached_at)) => {
                let parsed = serde_json::from_str(&data)?;
                if now - cached_at > ANIME_DETAILS_TTL_SECONDS {
                    Ok(CacheState::Stale(parsed))
                } else {
                    Ok(CacheState::Fresh(parsed))
                }
            }
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(CacheState::Miss),
            Err(e) => Err(StoreError::Db(e)),
        }
    }

    pub fn set<T: Serialize>(&self, anilist_id: u32, data: &T) -> Result<(), StoreError> {
        let now = Utc::now().timestamp();
        let json = serde_json::to_string(data)?;
        self.db.conn.execute(
            "INSERT OR REPLACE INTO anime_details_cache (anilist_id, data, cached_at)
             VALUES (?1, ?2, ?3)",
            rusqlite::params![anilist_id, json, now],
        )?;
        Ok(())
    }

    pub fn delete(&self, anilist_id: u32) -> Result<(), StoreError> {
        self.db.conn.execute(
            "DELETE FROM anime_details_cache WHERE anilist_id = ?1",
            [anilist_id],
        )?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
    struct TestPayload {
        id: u32,
    }

    #[test]
    fn anime_details_cache_tracks_fresh_and_stale() {
        let db = Database::open_in_memory().expect("in-memory db should open");
        db.migrate().expect("migrations should run");

        let cache = AnimeDetailsCache::new(&db);

        let miss = cache
            .get::<TestPayload>(42)
            .expect("cache get should succeed");
        assert!(matches!(miss, CacheState::Miss));

        let payload = TestPayload { id: 42 };
        cache.set(42, &payload).expect("cache set should succeed");

        let fresh = cache
            .get::<TestPayload>(42)
            .expect("cache get should succeed");
        match fresh {
            CacheState::Fresh(value) => assert_eq!(value, payload),
            _ => panic!("expected fresh cache state"),
        }

        let stale_at = Utc::now().timestamp() - ANIME_DETAILS_TTL_SECONDS - 1;
        db.conn
            .execute(
                "UPDATE anime_details_cache SET cached_at = ?1 WHERE anilist_id = ?2",
                rusqlite::params![stale_at, 42_u32],
            )
            .expect("timestamp update should succeed");

        let stale = cache
            .get::<TestPayload>(42)
            .expect("cache get should succeed");
        match stale {
            CacheState::Stale(value) => assert_eq!(value, payload),
            _ => panic!("expected stale cache state"),
        }
    }

    #[test]
    fn episode_cache_removes_stale_entries() {
        let db = Database::open_in_memory().expect("in-memory db should open");
        db.migrate().expect("migrations should run");

        let cache = EpisodeCache::new(&db);
        let payload = TestPayload { id: 101 };
        cache.set(101, &payload).expect("cache set should succeed");

        let stale_at = Utc::now().timestamp() - EPISODE_TTL_SECONDS - 1;
        db.conn
            .execute(
                "UPDATE tvdb_episode_cache SET cached_at = ?1 WHERE anilist_id = ?2",
                rusqlite::params![stale_at, 101_u32],
            )
            .expect("timestamp update should succeed");

        let stale = cache
            .get::<TestPayload>(101)
            .expect("cache get should succeed");
        assert!(stale.is_none());

        let remaining: i64 = db
            .conn
            .query_row(
                "SELECT COUNT(*) FROM tvdb_episode_cache WHERE anilist_id = ?1",
                [101_u32],
                |row| row.get(0),
            )
            .expect("count query should succeed");
        assert_eq!(remaining, 0);
    }

    #[test]
    fn anime_details_cache_delete_removes_entry() {
        let db = Database::open_in_memory().expect("in-memory db should open");
        db.migrate().expect("migrations should run");

        let cache = AnimeDetailsCache::new(&db);
        cache
            .set(8, &TestPayload { id: 8 })
            .expect("cache set should succeed");

        cache.delete(8).expect("cache delete should succeed");

        let state = cache
            .get::<TestPayload>(8)
            .expect("cache get should succeed");
        assert!(matches!(state, CacheState::Miss));
    }
}
