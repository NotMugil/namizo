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

            CREATE TABLE IF NOT EXISTS shelf (
                anilist_id       INTEGER PRIMARY KEY,
                title            TEXT    NOT NULL,
                cover_image      TEXT,
                banner_image     TEXT,
                format           TEXT,
                episode_total    INTEGER,
                score            INTEGER,
                genres           TEXT    NOT NULL DEFAULT '[]',
                anilist_status   TEXT,
                season           TEXT,
                season_year      INTEGER,
                popularity       INTEGER,
                average_score    INTEGER,
                start_date       TEXT,
                end_date         TEXT,
                rewatches        INTEGER NOT NULL DEFAULT 0,
                notes            TEXT,
                status           TEXT    NOT NULL,
                progress         INTEGER NOT NULL DEFAULT 0,
                progress_percent INTEGER NOT NULL DEFAULT 0,
                last_episode     INTEGER,
                last_watched_at  INTEGER,
                created_at       INTEGER NOT NULL,
                updated_at       INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_shelf_status ON shelf(status);
            CREATE INDEX IF NOT EXISTS idx_shelf_last_watched ON shelf(last_watched_at DESC);

            CREATE TABLE IF NOT EXISTS episode (
                anilist_id INTEGER NOT NULL,
                episode    INTEGER NOT NULL,
                percent    INTEGER NOT NULL,
                watched_at INTEGER NOT NULL,
                PRIMARY KEY (anilist_id, episode)
            );

            CREATE INDEX IF NOT EXISTS idx_episode_anilist ON episode(anilist_id);

            CREATE TABLE IF NOT EXISTS event (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                anilist_id INTEGER NOT NULL,
                episode    INTEGER NOT NULL,
                percent    INTEGER NOT NULL,
                watched_at INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_event_anilist_watched ON event(anilist_id, watched_at DESC);

            CREATE TABLE IF NOT EXISTS queue (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                anilist_id INTEGER NOT NULL,
                kind       TEXT    NOT NULL,
                payload    TEXT    NOT NULL,
                attempts   INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                sent_at    INTEGER
            );

            CREATE INDEX IF NOT EXISTS idx_queue_pending ON queue(sent_at, created_at);
        ",
        )?;

        add_column_if_missing(&self.conn, "shelf", "start_date TEXT")?;
        add_column_if_missing(&self.conn, "shelf", "end_date TEXT")?;
        add_column_if_missing(&self.conn, "shelf", "banner_image TEXT")?;
        add_column_if_missing(&self.conn, "shelf", "format TEXT")?;
        add_column_if_missing(&self.conn, "shelf", "genres TEXT NOT NULL DEFAULT '[]'")?;
        add_column_if_missing(&self.conn, "shelf", "anilist_status TEXT")?;
        add_column_if_missing(&self.conn, "shelf", "season TEXT")?;
        add_column_if_missing(&self.conn, "shelf", "season_year INTEGER")?;
        add_column_if_missing(&self.conn, "shelf", "popularity INTEGER")?;
        add_column_if_missing(&self.conn, "shelf", "average_score INTEGER")?;
        add_column_if_missing(&self.conn, "shelf", "rewatches INTEGER NOT NULL DEFAULT 0")?;
        add_column_if_missing(&self.conn, "shelf", "notes TEXT")?;
        self.conn.execute_batch(
            "
            UPDATE queue SET kind = 'UPDATE' WHERE kind = 'SAVE';
            UPDATE queue SET kind = 'PROGRESS' WHERE kind = 'STAMP';
            UPDATE queue SET kind = 'REMOVE' WHERE kind = 'DROP';
            ",
        )?;

        Ok(())
    }
}

fn add_column_if_missing(conn: &Connection, table: &str, definition: &str) -> Result<()> {
    let sql = format!("ALTER TABLE {table} ADD COLUMN {definition}");
    match conn.execute(&sql, []) {
        Ok(_) => Ok(()),
        Err(error) => {
            if let rusqlite::Error::SqliteFailure(_, Some(message)) = &error {
                if message.contains("duplicate column name") {
                    return Ok(());
                }
            }
            Err(error)
        }
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
                 AND name IN (
                    'tvdb_episode_cache',
                    'anime_details_cache',
                    'shelf',
                    'episode',
                    'event',
                    'queue'
                 )
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
                "episode".to_string(),
                "event".to_string(),
                "queue".to_string(),
                "shelf".to_string(),
                "tvdb_episode_cache".to_string()
            ]
        );

        let mut column_stmt = db
            .conn
            .prepare("PRAGMA table_info(shelf)")
            .expect("pragma should prepare");

        let columns = column_stmt
            .query_map([], |row| row.get::<_, String>(1))
            .expect("column query should run")
            .collect::<rusqlite::Result<Vec<String>>>()
            .expect("columns should collect");

        assert!(columns.contains(&"start_date".to_string()));
        assert!(columns.contains(&"end_date".to_string()));
        assert!(columns.contains(&"banner_image".to_string()));
        assert!(columns.contains(&"format".to_string()));
        assert!(columns.contains(&"genres".to_string()));
        assert!(columns.contains(&"anilist_status".to_string()));
        assert!(columns.contains(&"season".to_string()));
        assert!(columns.contains(&"season_year".to_string()));
        assert!(columns.contains(&"popularity".to_string()));
        assert!(columns.contains(&"average_score".to_string()));
        assert!(columns.contains(&"rewatches".to_string()));
        assert!(columns.contains(&"notes".to_string()));
    }
}