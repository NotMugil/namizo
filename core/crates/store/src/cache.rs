use chrono::Utc;
use serde::{Deserialize, Serialize};
use crate::{db::Database, error::StoreError};

const TTL_SECONDS: i64 = 7 * 24 * 60 * 60; // 7 days

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
                if now - cached_at > TTL_SECONDS {
                    // stale — delete and return None
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

    pub fn set<T: Serialize>(
        &self,
        anilist_id: u32,
        data: &T,
    ) -> Result<(), StoreError> {
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