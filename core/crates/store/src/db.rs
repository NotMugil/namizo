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
        self.conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS tvdb_episode_cache (
                anilist_id  INTEGER PRIMARY KEY,
                data        TEXT    NOT NULL,
                cached_at   INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS anime_details_cache (
                anilist_id  INTEGER PRIMARY KEY,
                data        TEXT    NOT NULL,
                cached_at   INTEGER NOT NULL
            );
        ",
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn migrate_creates_required_cache_tables() {
        let db = Database::open_in_memory().expect("in-memory db should open");
        db.migrate().expect("migrations should run");

        let mut statement = db
            .conn
            .prepare(
                "SELECT name FROM sqlite_master
                 WHERE type = 'table'
                 AND name IN ('tvdb_episode_cache', 'anime_details_cache')
                 ORDER BY name",
            )
            .expect("statement should prepare");

        let names = statement
            .query_map([], |row| row.get::<_, String>(0))
            .expect("query should run")
            .collect::<rusqlite::Result<Vec<String>>>()
            .expect("query rows should collect");

        assert_eq!(
            names,
            vec![
                "anime_details_cache".to_string(),
                "tvdb_episode_cache".to_string()
            ]
        );
    }
}