use crate::{db::Database, error::StoreError};
use domain::{SyncJob, SyncKind};
use rusqlite::{Connection, Row, params};

pub struct QueueStore<'a> {
    db: &'a Database,
}

impl<'a> QueueStore<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self { db }
    }

    pub fn push(&self, job: &SyncJob) -> Result<i64, StoreError> {
        Self::push_on(&self.db.conn, job)
    }

    pub fn pending(&self, limit: usize) -> Result<Vec<SyncJob>, StoreError> {
        Self::pending_on(&self.db.conn, limit)
    }

    pub fn push_on(conn: &Connection, job: &SyncJob) -> Result<i64, StoreError> {
        conn.execute(
            "
            INSERT INTO queue (anilist_id, kind, payload, attempts, created_at, sent_at)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6)
            ",
            params![
                job.anilist_id,
                job.kind.as_str(),
                job.payload,
                job.attempts,
                job.created_at,
                job.sent_at
            ],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn pending_on(conn: &Connection, limit: usize) -> Result<Vec<SyncJob>, StoreError> {
        let mut stmt = conn.prepare(
            "
            SELECT id, anilist_id, kind, payload, attempts, created_at, sent_at
            FROM queue
            WHERE sent_at IS NULL
            ORDER BY created_at ASC, id ASC
            LIMIT ?1
            ",
        )?;

        let raw = stmt
            .query_map([limit as i64], Self::read_row)?
            .collect::<rusqlite::Result<Vec<RawJob>>>()?;

        raw.into_iter()
            .map(TryInto::try_into)
            .collect::<Result<Vec<SyncJob>, StoreError>>()
    }

    fn read_row(row: &Row<'_>) -> rusqlite::Result<RawJob> {
        Ok(RawJob {
            id: row.get(0)?,
            anilist_id: row.get(1)?,
            kind: row.get(2)?,
            payload: row.get(3)?,
            attempts: row.get(4)?,
            created_at: row.get(5)?,
            sent_at: row.get(6)?,
        })
    }
}

#[derive(Debug)]
struct RawJob {
    id: i64,
    anilist_id: u32,
    kind: String,
    payload: String,
    attempts: u32,
    created_at: i64,
    sent_at: Option<i64>,
}

impl TryFrom<RawJob> for SyncJob {
    type Error = StoreError;

    fn try_from(value: RawJob) -> Result<Self, Self::Error> {
        let kind = SyncKind::parse(&value.kind)
            .ok_or_else(|| StoreError::InvalidData(format!("invalid sync kind: {}", value.kind)))?;

        Ok(SyncJob {
            id: Some(value.id),
            anilist_id: value.anilist_id,
            kind,
            payload: value.payload,
            attempts: value.attempts,
            created_at: value.created_at,
            sent_at: value.sent_at,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn queue_push_and_pending() {
        let db = Database::open_in_memory().expect("in-memory db should open");
        db.migrate().expect("migrations should run");
        let store = QueueStore::new(&db);

        store
            .push(&SyncJob {
                id: None,
                anilist_id: 1,
                kind: SyncKind::Update,
                payload: "{}".to_string(),
                attempts: 0,
                created_at: 1000,
                sent_at: None,
            })
            .expect("first push should succeed");

        store
            .push(&SyncJob {
                id: None,
                anilist_id: 2,
                kind: SyncKind::Progress,
                payload: "{}".to_string(),
                attempts: 0,
                created_at: 2000,
                sent_at: None,
            })
            .expect("second push should succeed");

        let pending = store.pending(10).expect("pending query should succeed");
        assert_eq!(pending.len(), 2);
        assert_eq!(pending[0].anilist_id, 1);
        assert_eq!(pending[1].anilist_id, 2);
        assert_eq!(pending[1].kind, SyncKind::Progress);
    }
}