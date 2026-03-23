use std::path::Path;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

use anilist::{AnilistClient, queries::details};
use chrono::{Datelike, Utc};
use domain::{EpisodeState, LibraryFacets, ShelfEntry, ShelfState, SyncJob, SyncKind, WatchEvent};
use serde_json::json;
use store::{Database, HistoryStore, LibraryStore, QueueStore, StoreError};

#[derive(Debug, Clone)]
struct MediaSnapshot {
    title: String,
    cover_image: Option<String>,
    banner_image: Option<String>,
    format: Option<String>,
    episode_total: Option<u32>,
    genres: Vec<String>,
    anilist_status: Option<String>,
    season: Option<String>,
    season_year: Option<u32>,
    popularity: Option<u32>,
    average_score: Option<u8>,
}

pub struct LibraryService {
    db: Mutex<Database>,
    client: AnilistClient,
}

impl LibraryService {
    pub fn new(db_path: &Path) -> Result<Self, StoreError> {
        let db = Database::open(db_path)?;
        db.migrate()?;
        Ok(Self {
            db: Mutex::new(db),
            client: AnilistClient::new(),
        })
    }

    #[cfg(test)]
    fn new_in_memory() -> Result<Self, StoreError> {
        let db = Database::open_in_memory()?;
        db.migrate()?;
        Ok(Self {
            db: Mutex::new(db),
            client: AnilistClient::new(),
        })
    }

    pub async fn fetch(&self, state: Option<ShelfState>) -> Result<Vec<ShelfEntry>, String> {
        let entries = {
            let db = self.db.lock().unwrap();
            LibraryStore::new(&db)
                .list(state)
                .map_err(|e| e.to_string())?
        };

        self.hydrate_entries(entries).await
    }

    pub async fn save(&self, mut entry: ShelfEntry) -> Result<ShelfEntry, String> {
        let now = now_ts();
        entry.progress_percent = entry.progress_percent.min(100);
        entry.score = entry.score.and_then(|value| {
            if value == 0 {
                None
            } else {
                Some(value.min(10))
            }
        });

        let existing = {
            let db = self.db.lock().unwrap();
            LibraryStore::new(&db)
                .get(entry.anilist_id)
                .map_err(|e| e.to_string())?
        };

        if let Some(value) = existing.as_ref() {
            copy_missing_fields(&mut entry, value);
        }

        if needs_media_hydration(&entry) {
            if let Some(snapshot) = self.fetch_media_snapshot(entry.anilist_id).await {
                apply_snapshot(&mut entry, &snapshot);
            }
        }

        entry.created_at = existing
            .as_ref()
            .map(|value| value.created_at)
            .unwrap_or_else(|| {
                if entry.created_at > 0 {
                    entry.created_at
                } else {
                    now
                }
            });
        entry.updated_at = now;

        let mut db = self.db.lock().unwrap();
        let tx = db.conn.transaction().map_err(|e| e.to_string())?;

        LibraryStore::upsert_on(&tx, &entry).map_err(|e| e.to_string())?;

        let payload = serde_json::to_string(&entry).map_err(|e| e.to_string())?;
        QueueStore::push_on(
            &tx,
            &SyncJob {
                id: None,
                anilist_id: entry.anilist_id,
                kind: SyncKind::Update,
                payload,
                attempts: 0,
                created_at: now,
                sent_at: None,
            },
        )
        .map_err(|e| e.to_string())?;

        tx.commit().map_err(|e| e.to_string())?;

        LibraryStore::get_on(&db.conn, entry.anilist_id)
            .map_err(|e| e.to_string())?
            .ok_or_else(|| "saved entry is missing".to_string())
    }

    pub async fn remove(&self, anilist_id: u32) -> Result<(), String> {
        let now = now_ts();
        let mut db = self.db.lock().unwrap();
        let tx = db.conn.transaction().map_err(|e| e.to_string())?;

        LibraryStore::delete_on(&tx, anilist_id).map_err(|e| e.to_string())?;

        QueueStore::push_on(
            &tx,
            &SyncJob {
                id: None,
                anilist_id,
                kind: SyncKind::Remove,
                payload: json!({ "anilist_id": anilist_id }).to_string(),
                attempts: 0,
                created_at: now,
                sent_at: None,
            },
        )
        .map_err(|e| e.to_string())?;

        tx.commit().map_err(|e| e.to_string())
    }

    pub async fn progress(&self, anilist_id: u32, episode: u32, percent: u8) -> Result<(), String> {
        let now = now_ts();
        let clamped_percent = percent.min(100);

        let existing = {
            let db = self.db.lock().unwrap();
            LibraryStore::new(&db)
                .get(anilist_id)
                .map_err(|e| e.to_string())?
        };

        let should_fetch_snapshot = existing.as_ref().map(needs_media_hydration).unwrap_or(true);

        let snapshot = if should_fetch_snapshot {
            self.fetch_media_snapshot(anilist_id).await
        } else {
            None
        };

        let mut db = self.db.lock().unwrap();
        let tx = db.conn.transaction().map_err(|e| e.to_string())?;

        if let Some(seed) = build_seed_entry(anilist_id, now, existing.as_ref(), snapshot.as_ref())
        {
            LibraryStore::upsert_on(&tx, &seed).map_err(|e| e.to_string())?;
        }

        HistoryStore::upsert_episode_on(
            &tx,
            &EpisodeState {
                anilist_id,
                episode,
                percent: clamped_percent,
                watched_at: now,
            },
        )
        .map_err(|e| e.to_string())?;

        HistoryStore::append_event_on(
            &tx,
            &WatchEvent {
                id: None,
                anilist_id,
                episode,
                percent: clamped_percent,
                watched_at: now,
            },
        )
        .map_err(|e| e.to_string())?;

        LibraryStore::apply_stamp_on(&tx, anilist_id, episode, clamped_percent, now)
            .map_err(|e| e.to_string())?;

        QueueStore::push_on(
            &tx,
            &SyncJob {
                id: None,
                anilist_id,
                kind: SyncKind::Progress,
                payload: json!({
                    "anilist_id": anilist_id,
                    "episode": episode,
                    "percent": clamped_percent,
                    "watched_at": now
                })
                .to_string(),
                attempts: 0,
                created_at: now,
                sent_at: None,
            },
        )
        .map_err(|e| e.to_string())?;

        tx.commit().map_err(|e| e.to_string())
    }

    pub async fn resume(&self) -> Result<Vec<ShelfEntry>, String> {
        let entries = {
            let db = self.db.lock().unwrap();
            LibraryStore::new(&db).resume().map_err(|e| e.to_string())?
        };

        self.hydrate_entries(entries).await
    }

    pub async fn facets(&self) -> Result<LibraryFacets, String> {
        let mut genres = self.client.fetch_genres().await.map_err(|e| e.to_string())?;
        genres.sort_unstable_by_key(|value| value.to_lowercase());
        genres.dedup_by(|left, right| left.eq_ignore_ascii_case(right));

        Ok(LibraryFacets {
            genres,
            release_statuses: vec![
                "FINISHED".to_string(),
                "RELEASING".to_string(),
                "NOT_YET_RELEASED".to_string(),
            ],
            seasons: vec![
                "WINTER".to_string(),
                "SPRING".to_string(),
                "SUMMER".to_string(),
                "FALL".to_string(),
            ],
            years: build_years(),
        })
    }

    pub async fn history(
        &self,
        anilist_id: u32,
    ) -> Result<(Vec<EpisodeState>, Vec<WatchEvent>), String> {
        let db = self.db.lock().unwrap();
        let store = HistoryStore::new(&db);
        let episodes = store.episodes(anilist_id).map_err(|e| e.to_string())?;
        let events = store.events(anilist_id).map_err(|e| e.to_string())?;
        Ok((episodes, events))
    }

    async fn fetch_media_snapshot(&self, anilist_id: u32) -> Option<MediaSnapshot> {
        let details = details::fetch_details(&self.client, anilist_id)
            .await
            .ok()?;
        Some(MediaSnapshot {
            title: details.title,
            cover_image: Some(details.cover_image),
            banner_image: details.banner_image,
            format: details.format,
            episode_total: details.episode_count,
            genres: details.genres,
            anilist_status: details.status,
            season: details.season,
            season_year: details.season_year,
            popularity: details.popularity,
            average_score: details.average_score,
        })
    }

    async fn hydrate_entries(&self, entries: Vec<ShelfEntry>) -> Result<Vec<ShelfEntry>, String> {
        if entries.is_empty() {
            return Ok(entries);
        }

        let mut next_entries = entries;
        let mut updated = Vec::new();

        for entry in &mut next_entries {
            if !needs_media_hydration(entry) {
                continue;
            }

            let Some(snapshot) = self.fetch_media_snapshot(entry.anilist_id).await else {
                continue;
            };

            if apply_snapshot(entry, &snapshot) {
                updated.push(entry.clone());
            }
        }

        if updated.is_empty() {
            return Ok(next_entries);
        }

        let mut db = self.db.lock().unwrap();
        let tx = db.conn.transaction().map_err(|e| e.to_string())?;
        for entry in &updated {
            LibraryStore::upsert_on(&tx, entry).map_err(|e| e.to_string())?;
        }
        tx.commit().map_err(|e| e.to_string())?;

        Ok(next_entries)
    }
}

fn needs_media_hydration(entry: &ShelfEntry) -> bool {
    entry.title.trim().is_empty()
        || entry.cover_image.as_deref().is_none_or(str::is_empty)
        || entry.banner_image.as_deref().is_none_or(str::is_empty)
        || entry.format.as_deref().is_none_or(str::is_empty)
        || entry.episode_total.is_none()
        || entry.genres.is_empty()
        || entry.anilist_status.as_deref().is_none_or(str::is_empty)
        || entry.season.as_deref().is_none_or(str::is_empty)
        || entry.season_year.is_none()
        || entry.popularity.is_none()
        || entry.average_score.is_none()
}

fn copy_missing_fields(entry: &mut ShelfEntry, existing: &ShelfEntry) {
    if entry.title.trim().is_empty() && !existing.title.trim().is_empty() {
        entry.title = existing.title.clone();
    }
    if entry.cover_image.as_deref().is_none_or(str::is_empty) {
        entry.cover_image = existing.cover_image.clone();
    }
    if entry.banner_image.as_deref().is_none_or(str::is_empty) {
        entry.banner_image = existing.banner_image.clone();
    }
    if entry.format.as_deref().is_none_or(str::is_empty) {
        entry.format = existing.format.clone();
    }
    if entry.episode_total.is_none() {
        entry.episode_total = existing.episode_total;
    }
    if entry.genres.is_empty() && !existing.genres.is_empty() {
        entry.genres = existing.genres.clone();
    }
    if entry.anilist_status.as_deref().is_none_or(str::is_empty) {
        entry.anilist_status = existing.anilist_status.clone();
    }
    if entry.season.as_deref().is_none_or(str::is_empty) {
        entry.season = existing.season.clone();
    }
    if entry.season_year.is_none() {
        entry.season_year = existing.season_year;
    }
    if entry.popularity.is_none() {
        entry.popularity = existing.popularity;
    }
    if entry.average_score.is_none() {
        entry.average_score = existing.average_score;
    }
}

fn apply_snapshot(entry: &mut ShelfEntry, snapshot: &MediaSnapshot) -> bool {
    let mut changed = false;

    if entry.title.trim().is_empty() && !snapshot.title.trim().is_empty() {
        entry.title = snapshot.title.clone();
        changed = true;
    }
    if entry.cover_image.as_deref().is_none_or(str::is_empty) {
        entry.cover_image = snapshot.cover_image.clone();
        changed = true;
    }
    if entry.banner_image.as_deref().is_none_or(str::is_empty) {
        entry.banner_image = snapshot.banner_image.clone();
        changed = true;
    }
    if entry.format.as_deref().is_none_or(str::is_empty) {
        entry.format = snapshot.format.clone();
        changed = true;
    }
    if entry.episode_total.is_none() {
        entry.episode_total = snapshot.episode_total;
        changed = true;
    }
    if entry.genres.is_empty() && !snapshot.genres.is_empty() {
        entry.genres = snapshot.genres.clone();
        changed = true;
    }
    if entry.anilist_status.as_deref().is_none_or(str::is_empty) {
        entry.anilist_status = snapshot.anilist_status.clone();
        changed = true;
    }
    if entry.season.as_deref().is_none_or(str::is_empty) {
        entry.season = snapshot.season.clone();
        changed = true;
    }
    if entry.season_year.is_none() {
        entry.season_year = snapshot.season_year;
        changed = true;
    }
    if entry.popularity.is_none() {
        entry.popularity = snapshot.popularity;
        changed = true;
    }
    if entry.average_score.is_none() {
        entry.average_score = snapshot.average_score;
        changed = true;
    }

    changed
}

fn build_seed_entry(
    anilist_id: u32,
    now: i64,
    existing: Option<&ShelfEntry>,
    snapshot: Option<&MediaSnapshot>,
) -> Option<ShelfEntry> {
    let mut entry = existing.cloned().unwrap_or(ShelfEntry {
        anilist_id,
        title: String::new(),
        cover_image: None,
        banner_image: None,
        format: None,
        episode_total: None,
        score: None,
        genres: Vec::new(),
        anilist_status: None,
        season: None,
        season_year: None,
        popularity: None,
        average_score: None,
        start_date: None,
        end_date: None,
        rewatches: 0,
        notes: None,
        status: ShelfState::Watching,
        progress: 0,
        progress_percent: 0,
        last_episode: None,
        last_watched_at: None,
        created_at: now,
        updated_at: now,
    });

    if let Some(value) = snapshot {
        apply_snapshot(&mut entry, value);
    }

    if existing.is_some() || snapshot.is_some() {
        if existing.is_none() {
            entry.created_at = now;
        }
        entry.updated_at = now;
        Some(entry)
    } else {
        None
    }
}

fn now_ts() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}

fn build_years() -> Vec<u32> {
    let max_year = (Utc::now().year() + 1).max(1950);
    (1950..=max_year).rev().map(|value| value as u32).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;
    use std::time::Duration;

    fn sample_entry(anilist_id: u32, status: ShelfState) -> ShelfEntry {
        ShelfEntry {
            anilist_id,
            title: format!("Anime {anilist_id}"),
            cover_image: Some("https://cdn.anilist.test/cover.jpg".to_string()),
            banner_image: Some("https://cdn.anilist.test/banner.jpg".to_string()),
            format: Some("TV".to_string()),
            episode_total: Some(12),
            score: Some(8),
            genres: vec!["Action".to_string()],
            anilist_status: Some("FINISHED".to_string()),
            season: Some("FALL".to_string()),
            season_year: Some(2024),
            popularity: Some(10_000),
            average_score: Some(81),
            start_date: None,
            end_date: None,
            rewatches: 0,
            notes: None,
            status,
            progress: 0,
            progress_percent: 0,
            last_episode: None,
            last_watched_at: None,
            created_at: 0,
            updated_at: 0,
        }
    }

    #[tokio::test]
    async fn fetch_filters_by_state() {
        let service = LibraryService::new_in_memory().expect("service should initialize");

        service
            .save(sample_entry(1, ShelfState::Watching))
            .await
            .expect("save watching should succeed");
        service
            .save(sample_entry(2, ShelfState::Planning))
            .await
            .expect("save planning should succeed");

        let watching = service
            .fetch(Some(ShelfState::Watching))
            .await
            .expect("fetch should succeed");

        assert_eq!(watching.len(), 1);
        assert_eq!(watching[0].anilist_id, 1);
    }

    #[tokio::test]
    async fn progress_writes_history_layers_and_queue() {
        let service = LibraryService::new_in_memory().expect("service should initialize");

        service
            .save(sample_entry(99, ShelfState::Planning))
            .await
            .expect("save should succeed");
        service
            .progress(99, 3, 150)
            .await
            .expect("progress should succeed");

        let stamped = service
            .fetch(Some(ShelfState::Watching))
            .await
            .expect("fetch should succeed");
        assert_eq!(stamped.len(), 1);
        assert_eq!(stamped[0].anilist_id, 99);
        assert_eq!(stamped[0].progress, 3);
        assert_eq!(stamped[0].progress_percent, 100);
        assert_eq!(stamped[0].last_episode, Some(3));

        let (episodes, events) = service.history(99).await.expect("history should succeed");
        assert_eq!(episodes.len(), 1);
        assert_eq!(episodes[0].episode, 3);
        assert_eq!(episodes[0].percent, 100);
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].episode, 3);

        let db = service.db.lock().unwrap();
        let pending = QueueStore::new(&db)
            .pending(20)
            .expect("pending queue should load");
        assert!(pending.iter().any(|job| job.kind == SyncKind::Progress));
    }

    #[tokio::test]
    async fn resume_orders_by_last_watched_desc_and_excludes_completed() {
        let service = LibraryService::new_in_memory().expect("service should initialize");

        service
            .save(sample_entry(7, ShelfState::Watching))
            .await
            .expect("save should succeed");
        service
            .save(sample_entry(8, ShelfState::Watching))
            .await
            .expect("save should succeed");

        let mut done = sample_entry(9, ShelfState::Completed);
        done.progress = 12;
        done.last_episode = Some(12);
        done.last_watched_at = Some(10);
        service.save(done).await.expect("save should succeed");

        service
            .progress(7, 1, 20)
            .await
            .expect("progress should succeed");
        thread::sleep(Duration::from_secs(1));
        service
            .progress(8, 1, 20)
            .await
            .expect("progress should succeed");

        let resume = service.resume().await.expect("resume should succeed");
        assert_eq!(resume.len(), 2);
        assert_eq!(resume[0].anilist_id, 8);
        assert_eq!(resume[1].anilist_id, 7);
    }

    #[test]
    fn build_years_returns_descending_range() {
        let years = build_years();
        assert!(!years.is_empty());
        assert_eq!(*years.last().expect("year list should have last"), 1950);
        assert!(years.windows(2).all(|pair| pair[0] >= pair[1]));
    }
}