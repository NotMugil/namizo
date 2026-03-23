use crate::{db::Database, error::StoreError};
use domain::{ShelfEntry, ShelfState};
use rusqlite::{Connection, OptionalExtension, Row, params};
use serde_json;

pub struct LibraryStore<'a> {
    db: &'a Database,
}

#[derive(Debug, Clone)]
struct ShelfRow {
    anilist_id: u32,
    title: String,
    cover_image: Option<String>,
    banner_image: Option<String>,
    format: Option<String>,
    episode_total: Option<u32>,
    score: Option<u8>,
    genres: Option<String>,
    anilist_status: Option<String>,
    season: Option<String>,
    season_year: Option<u32>,
    popularity: Option<u32>,
    average_score: Option<u8>,
    start_date: Option<String>,
    end_date: Option<String>,
    rewatches: u32,
    notes: Option<String>,
    status: String,
    progress: u32,
    progress_percent: u8,
    last_episode: Option<u32>,
    last_watched_at: Option<i64>,
    created_at: i64,
    updated_at: i64,
}

impl TryFrom<ShelfRow> for ShelfEntry {
    type Error = StoreError;

    fn try_from(value: ShelfRow) -> Result<Self, Self::Error> {
        let status = ShelfState::parse(&value.status).ok_or_else(|| {
            StoreError::InvalidData(format!("invalid shelf status: {}", value.status))
        })?;

        Ok(Self {
            anilist_id: value.anilist_id,
            title: value.title,
            cover_image: value.cover_image,
            banner_image: value.banner_image,
            format: value.format,
            episode_total: value.episode_total,
            score: value.score,
            genres: parse_genres(value.genres.as_deref())?,
            anilist_status: value.anilist_status,
            season: value.season,
            season_year: value.season_year,
            popularity: value.popularity,
            average_score: value.average_score,
            start_date: value.start_date,
            end_date: value.end_date,
            rewatches: value.rewatches,
            notes: value.notes,
            status,
            progress: value.progress,
            progress_percent: value.progress_percent,
            last_episode: value.last_episode,
            last_watched_at: value.last_watched_at,
            created_at: value.created_at,
            updated_at: value.updated_at,
        })
    }
}

impl<'a> LibraryStore<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self { db }
    }

    pub fn list(&self, state: Option<ShelfState>) -> Result<Vec<ShelfEntry>, StoreError> {
        Self::list_on(&self.db.conn, state)
    }

    pub fn resume(&self) -> Result<Vec<ShelfEntry>, StoreError> {
        Self::resume_on(&self.db.conn)
    }

    pub fn get(&self, anilist_id: u32) -> Result<Option<ShelfEntry>, StoreError> {
        Self::get_on(&self.db.conn, anilist_id)
    }

    pub fn upsert(&self, entry: &ShelfEntry) -> Result<ShelfEntry, StoreError> {
        Self::upsert_on(&self.db.conn, entry)?;
        Self::get_on(&self.db.conn, entry.anilist_id)?
            .ok_or_else(|| StoreError::InvalidData("upsert succeeded but row missing".to_string()))
    }

    pub fn delete(&self, anilist_id: u32) -> Result<(), StoreError> {
        Self::delete_on(&self.db.conn, anilist_id)
    }

    pub fn list_on(
        conn: &Connection,
        state: Option<ShelfState>,
    ) -> Result<Vec<ShelfEntry>, StoreError> {
        let sql_all = "
            SELECT anilist_id, title, cover_image, banner_image, format, episode_total, score, genres, anilist_status, season, season_year, popularity, average_score, start_date, end_date, rewatches, notes, status,
                   progress, progress_percent, last_episode, last_watched_at, created_at, updated_at
            FROM shelf
            ORDER BY updated_at DESC, anilist_id DESC
        ";
        let sql_filtered = "
            SELECT anilist_id, title, cover_image, banner_image, format, episode_total, score, genres, anilist_status, season, season_year, popularity, average_score, start_date, end_date, rewatches, notes, status,
                   progress, progress_percent, last_episode, last_watched_at, created_at, updated_at
            FROM shelf
            WHERE status = ?1
            ORDER BY updated_at DESC, anilist_id DESC
        ";

        let mut stmt = if state.is_some() {
            conn.prepare(sql_filtered)?
        } else {
            conn.prepare(sql_all)?
        };

        let rows = if let Some(state) = state {
            stmt.query_map([state.as_str()], Self::read_row)?
                .collect::<rusqlite::Result<Vec<ShelfRow>>>()?
        } else {
            stmt.query_map([], Self::read_row)?
                .collect::<rusqlite::Result<Vec<ShelfRow>>>()?
        };

        rows.into_iter().map(TryInto::try_into).collect()
    }

    pub fn resume_on(conn: &Connection) -> Result<Vec<ShelfEntry>, StoreError> {
        let mut stmt = conn.prepare(
            "
            SELECT anilist_id, title, cover_image, banner_image, format, episode_total, score, genres, anilist_status, season, season_year, popularity, average_score, start_date, end_date, rewatches, notes, status,
                   progress, progress_percent, last_episode, last_watched_at, created_at, updated_at
            FROM shelf
            WHERE status IN ('WATCHING', 'REWATCHING', 'PAUSED')
              AND last_watched_at IS NOT NULL
              AND progress > 0
              AND (episode_total IS NULL OR progress < episode_total)
            ORDER BY last_watched_at DESC, anilist_id DESC
            ",
        )?;

        let rows = stmt
            .query_map([], Self::read_row)?
            .collect::<rusqlite::Result<Vec<ShelfRow>>>()?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    pub fn get_on(conn: &Connection, anilist_id: u32) -> Result<Option<ShelfEntry>, StoreError> {
        let mut stmt = conn.prepare(
            "
            SELECT anilist_id, title, cover_image, banner_image, format, episode_total, score, genres, anilist_status, season, season_year, popularity, average_score, start_date, end_date, rewatches, notes, status,
                   progress, progress_percent, last_episode, last_watched_at, created_at, updated_at
            FROM shelf
            WHERE anilist_id = ?1
            ",
        )?;

        let row = stmt.query_row([anilist_id], Self::read_row).optional()?;

        row.map(TryInto::try_into).transpose()
    }

    pub fn upsert_on(conn: &Connection, entry: &ShelfEntry) -> Result<(), StoreError> {
        let genres = serde_json::to_string(&entry.genres)?;

        conn.execute(
            "
            INSERT INTO shelf (
                anilist_id, title, cover_image, banner_image, format, episode_total, score, genres, anilist_status, season, season_year, popularity, average_score, start_date, end_date, rewatches, notes, status,
                progress, progress_percent, last_episode, last_watched_at, created_at, updated_at
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24)
            ON CONFLICT(anilist_id) DO UPDATE SET
                title = excluded.title,
                cover_image = excluded.cover_image,
                banner_image = excluded.banner_image,
                format = excluded.format,
                episode_total = excluded.episode_total,
                score = excluded.score,
                genres = excluded.genres,
                anilist_status = excluded.anilist_status,
                season = excluded.season,
                season_year = excluded.season_year,
                popularity = excluded.popularity,
                average_score = excluded.average_score,
                start_date = excluded.start_date,
                end_date = excluded.end_date,
                rewatches = excluded.rewatches,
                notes = excluded.notes,
                status = excluded.status,
                progress = excluded.progress,
                progress_percent = excluded.progress_percent,
                last_episode = excluded.last_episode,
                last_watched_at = excluded.last_watched_at,
                updated_at = excluded.updated_at
            ",
            params![
                entry.anilist_id,
                entry.title,
                entry.cover_image,
                entry.banner_image,
                entry.format,
                entry.episode_total,
                entry.score,
                genres,
                entry.anilist_status,
                entry.season,
                entry.season_year,
                entry.popularity,
                entry.average_score,
                entry.start_date,
                entry.end_date,
                entry.rewatches,
                entry.notes,
                entry.status.as_str(),
                entry.progress,
                entry.progress_percent,
                entry.last_episode,
                entry.last_watched_at,
                entry.created_at,
                entry.updated_at,
            ],
        )?;
        Ok(())
    }

    pub fn delete_on(conn: &Connection, anilist_id: u32) -> Result<(), StoreError> {
        conn.execute("DELETE FROM shelf WHERE anilist_id = ?1", [anilist_id])?;
        Ok(())
    }

    pub fn apply_stamp_on(
        conn: &Connection,
        anilist_id: u32,
        episode: u32,
        percent: u8,
        watched_at: i64,
    ) -> Result<(), StoreError> {
        let clamped_percent = percent.min(100);
        let existing = Self::get_on(conn, anilist_id)?;

        match existing {
            Some(entry) => {
                let next_status = if entry.status == ShelfState::Planning {
                    ShelfState::Watching
                } else {
                    entry.status
                };
                let next_progress = entry.progress.max(episode);

                conn.execute(
                    "
                    UPDATE shelf
                    SET status = ?2,
                        progress = ?3,
                        progress_percent = ?4,
                        last_episode = ?5,
                        last_watched_at = ?6,
                        updated_at = ?7
                    WHERE anilist_id = ?1
                    ",
                    params![
                        anilist_id,
                        next_status.as_str(),
                        next_progress,
                        clamped_percent,
                        episode,
                        watched_at,
                        watched_at,
                    ],
                )?;
            }
            None => {
                conn.execute(
                    "
                    INSERT INTO shelf (
                        anilist_id, title, cover_image, banner_image, format, episode_total, score, genres, anilist_status, season, season_year, popularity, average_score, start_date, end_date, rewatches, notes, status,
                        progress, progress_percent, last_episode, last_watched_at, created_at, updated_at
                    ) VALUES (?1, '', NULL, NULL, NULL, NULL, NULL, '[]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, 'WATCHING', ?2, ?3, ?4, ?5, ?6, ?6)
                    ",
                    params![anilist_id, episode, clamped_percent, episode, watched_at, watched_at],
                )?;
            }
        }

        Ok(())
    }

    fn read_row(row: &Row<'_>) -> rusqlite::Result<ShelfRow> {
        Ok(ShelfRow {
            anilist_id: row.get(0)?,
            title: row.get(1)?,
            cover_image: row.get(2)?,
            banner_image: row.get(3)?,
            format: row.get(4)?,
            episode_total: row.get(5)?,
            score: row.get(6)?,
            genres: row.get(7)?,
            anilist_status: row.get(8)?,
            season: row.get(9)?,
            season_year: row.get(10)?,
            popularity: row.get(11)?,
            average_score: row.get(12)?,
            start_date: row.get(13)?,
            end_date: row.get(14)?,
            rewatches: row.get(15)?,
            notes: row.get(16)?,
            status: row.get(17)?,
            progress: row.get(18)?,
            progress_percent: row.get(19)?,
            last_episode: row.get(20)?,
            last_watched_at: row.get(21)?,
            created_at: row.get(22)?,
            updated_at: row.get(23)?,
        })
    }
}

fn parse_genres(raw: Option<&str>) -> Result<Vec<String>, StoreError> {
    let Some(raw) = raw else {
        return Ok(Vec::new());
    };
    if raw.trim().is_empty() {
        return Ok(Vec::new());
    }
    match serde_json::from_str::<Vec<String>>(raw) {
        Ok(genres) => Ok(genres),
        Err(_) => Ok(raw
            .split(',')
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned)
            .collect()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_entry(anilist_id: u32, status: ShelfState, updated_at: i64) -> ShelfEntry {
        ShelfEntry {
            anilist_id,
            title: format!("Anime {}", anilist_id),
            cover_image: Some("https://cdn.anilist.test/cover.jpg".to_string()),
            banner_image: Some("https://cdn.anilist.test/banner.jpg".to_string()),
            format: Some("TV".to_string()),
            episode_total: Some(24),
            score: Some(8),
            genres: vec!["Action".to_string(), "Drama".to_string()],
            anilist_status: Some("RELEASING".to_string()),
            season: Some("SPRING".to_string()),
            season_year: Some(2026),
            popularity: Some(12_345),
            average_score: Some(82),
            start_date: Some("2026-01-01".to_string()),
            end_date: None,
            rewatches: 0,
            notes: None,
            status,
            progress: 1,
            progress_percent: 10,
            last_episode: Some(1),
            last_watched_at: Some(updated_at),
            created_at: updated_at - 100,
            updated_at,
        }
    }

    #[test]
    fn shelf_upsert_list_filter_delete() {
        let db = Database::open_in_memory().expect("in-memory db should open");
        db.migrate().expect("migrations should run");
        let store = LibraryStore::new(&db);

        let first = sample_entry(1, ShelfState::Watching, 1000);
        let second = sample_entry(2, ShelfState::Planning, 2000);

        store.upsert(&first).expect("first insert should succeed");
        store.upsert(&second).expect("second insert should succeed");

        let watching = store
            .list(Some(ShelfState::Watching))
            .expect("watching query should succeed");
        assert_eq!(watching.len(), 1);
        assert_eq!(watching[0].anilist_id, 1);

        let mut updated = first.clone();
        updated.title = "Updated".to_string();
        updated.created_at = 10;
        updated.updated_at = 3000;
        store.upsert(&updated).expect("upsert should succeed");

        let found = store
            .get(1)
            .expect("get should succeed")
            .expect("row exists");
        assert_eq!(found.title, "Updated");
        assert_eq!(found.created_at, first.created_at);
        assert_eq!(found.updated_at, 3000);
        assert_eq!(found.start_date.as_deref(), Some("2026-01-01"));
        assert_eq!(
            found.genres,
            vec!["Action".to_string(), "Drama".to_string()]
        );
        assert_eq!(found.season_year, Some(2026));

        let all = store.list(None).expect("list should succeed");
        assert_eq!(all.len(), 2);
        assert_eq!(all[0].anilist_id, 1);

        store.delete(2).expect("delete should succeed");
        let remaining = store.list(None).expect("list should succeed");
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].anilist_id, 1);
    }

    #[test]
    fn apply_stamp_promotes_planning_and_updates_progress() {
        let db = Database::open_in_memory().expect("in-memory db should open");
        db.migrate().expect("migrations should run");
        let store = LibraryStore::new(&db);

        let mut entry = sample_entry(11, ShelfState::Planning, 1000);
        entry.progress = 2;
        entry.progress_percent = 20;
        store.upsert(&entry).expect("insert should succeed");

        LibraryStore::apply_stamp_on(&db.conn, 11, 5, 130, 5000).expect("stamp should succeed");

        let stamped = store
            .get(11)
            .expect("get should succeed")
            .expect("row exists");
        assert_eq!(stamped.status, ShelfState::Watching);
        assert_eq!(stamped.progress, 5);
        assert_eq!(stamped.progress_percent, 100);
        assert_eq!(stamped.last_episode, Some(5));
        assert_eq!(stamped.last_watched_at, Some(5000));
    }
}