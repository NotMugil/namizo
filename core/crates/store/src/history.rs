use crate::{db::Database, error::StoreError};
use domain::{EpisodeState, WatchEvent};
use rusqlite::{Connection, Row, params};

pub struct HistoryStore<'a> {
    db: &'a Database,
}

impl<'a> HistoryStore<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self { db }
    }

    pub fn upsert_episode(&self, state: &EpisodeState) -> Result<(), StoreError> {
        Self::upsert_episode_on(&self.db.conn, state)
    }

    pub fn append_event(&self, event: &WatchEvent) -> Result<i64, StoreError> {
        Self::append_event_on(&self.db.conn, event)
    }

    pub fn episodes(&self, anilist_id: u32) -> Result<Vec<EpisodeState>, StoreError> {
        Self::episodes_on(&self.db.conn, anilist_id)
    }

    pub fn events(&self, anilist_id: u32) -> Result<Vec<WatchEvent>, StoreError> {
        Self::events_on(&self.db.conn, anilist_id)
    }

    pub fn upsert_episode_on(conn: &Connection, state: &EpisodeState) -> Result<(), StoreError> {
        conn.execute(
            "
            INSERT INTO episode (anilist_id, episode, percent, watched_at)
            VALUES (?1, ?2, ?3, ?4)
            ON CONFLICT(anilist_id, episode) DO UPDATE SET
                percent = excluded.percent,
                watched_at = excluded.watched_at
            ",
            params![
                state.anilist_id,
                state.episode,
                state.percent.min(100),
                state.watched_at
            ],
        )?;
        Ok(())
    }

    pub fn append_event_on(conn: &Connection, event: &WatchEvent) -> Result<i64, StoreError> {
        conn.execute(
            "
            INSERT INTO event (anilist_id, episode, percent, watched_at)
            VALUES (?1, ?2, ?3, ?4)
            ",
            params![
                event.anilist_id,
                event.episode,
                event.percent.min(100),
                event.watched_at
            ],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn episodes_on(
        conn: &Connection,
        anilist_id: u32,
    ) -> Result<Vec<EpisodeState>, StoreError> {
        let mut stmt = conn.prepare(
            "
            SELECT anilist_id, episode, percent, watched_at
            FROM episode
            WHERE anilist_id = ?1
            ORDER BY episode ASC
            ",
        )?;

        stmt.query_map([anilist_id], Self::read_episode)?
            .collect::<rusqlite::Result<Vec<EpisodeState>>>()
            .map_err(StoreError::from)
    }

    pub fn events_on(conn: &Connection, anilist_id: u32) -> Result<Vec<WatchEvent>, StoreError> {
        let mut stmt = conn.prepare(
            "
            SELECT id, anilist_id, episode, percent, watched_at
            FROM event
            WHERE anilist_id = ?1
            ORDER BY watched_at DESC, id DESC
            ",
        )?;

        stmt.query_map([anilist_id], Self::read_event)?
            .collect::<rusqlite::Result<Vec<WatchEvent>>>()
            .map_err(StoreError::from)
    }

    fn read_episode(row: &Row<'_>) -> rusqlite::Result<EpisodeState> {
        Ok(EpisodeState {
            anilist_id: row.get(0)?,
            episode: row.get(1)?,
            percent: row.get(2)?,
            watched_at: row.get(3)?,
        })
    }

    fn read_event(row: &Row<'_>) -> rusqlite::Result<WatchEvent> {
        Ok(WatchEvent {
            id: row.get(0)?,
            anilist_id: row.get(1)?,
            episode: row.get(2)?,
            percent: row.get(3)?,
            watched_at: row.get(4)?,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn history_tracks_latest_episode_state_and_full_event_log() {
        let db = Database::open_in_memory().expect("in-memory db should open");
        db.migrate().expect("migrations should run");
        let store = HistoryStore::new(&db);

        let first = EpisodeState {
            anilist_id: 42,
            episode: 7,
            percent: 20,
            watched_at: 1000,
        };
        store
            .upsert_episode(&first)
            .expect("first episode upsert should succeed");

        let update = EpisodeState {
            anilist_id: 42,
            episode: 7,
            percent: 95,
            watched_at: 2000,
        };
        store
            .upsert_episode(&update)
            .expect("episode update should succeed");

        store
            .append_event(&WatchEvent {
                id: None,
                anilist_id: 42,
                episode: 7,
                percent: 20,
                watched_at: 1000,
            })
            .expect("first event should append");
        store
            .append_event(&WatchEvent {
                id: None,
                anilist_id: 42,
                episode: 7,
                percent: 95,
                watched_at: 2000,
            })
            .expect("second event should append");

        let episodes = store.episodes(42).expect("episode list should succeed");
        assert_eq!(episodes.len(), 1);
        assert_eq!(episodes[0].percent, 95);
        assert_eq!(episodes[0].watched_at, 2000);

        let events = store.events(42).expect("event list should succeed");
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].percent, 95);
        assert_eq!(events[1].percent, 20);
    }
}