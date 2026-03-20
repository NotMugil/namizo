use rusqlite::{Connection, Result};
use std::path::Path;

pub struct Database {
    pub conn: Connection,
}

impl Database {
    pub fn open(path: &Path) -> Result<Self> {
        let conn = Connection::open(path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        Ok(Self { conn })
    }

    pub fn open_in_memory() -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        Ok(Self { conn })
    }

    pub fn migrate(&self) -> Result<()> {
        self.conn.execute_batch("
            CREATE TABLE IF NOT EXISTS tvdb_episode_cache (
                anilist_id  INTEGER PRIMARY KEY,
                data        TEXT    NOT NULL,
                cached_at   INTEGER NOT NULL
            );
        ")
    }
}