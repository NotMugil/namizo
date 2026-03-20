use crate::error::TvdbError;
use reqwest::Client;
use serde_json::Value;
use std::path::{Path, PathBuf};

const MAPPING_URL: &str =
    "https://raw.githubusercontent.com/Fribb/anime-lists/master/anime-list-full.json";

const UPDATE_INTERVAL_SECONDS: i64 = 24 * 60 * 60; // 24 hours

#[derive(Debug, Clone, Copy)]
pub struct TvdbMappingMatch {
    pub tvdb_id: u64,
    pub season_tvdb: Option<u32>,
}

pub async fn load_mapping(
    app_data_dir: &Path,
    bundled_path: &Path,
    client: &Client,
) -> Result<Vec<Value>, TvdbError> {
    let cached_path = app_data_dir.join("anime-list-full.json");
    println!(
        "[TVDB][mapping] load start cached_path={} bundled_path={}",
        cached_path.display(),
        bundled_path.display()
    );

    // try to update if stale or missing
    let should_update = should_update(&cached_path);
    println!("[TVDB][mapping] should_update={}", should_update);
    if should_update {
        match download_mapping(client, &cached_path).await {
            Ok(_) => {
                println!("[TVDB][mapping] mapping downloaded to {}", cached_path.display());
            }
            Err(err) => {
                // download failed - will fall back to cached or bundled
                eprintln!("[TVDB][mapping] download failed err={}", err);
            }
        }
    }

    // load from app data if exists, else fall back to bundled
    let path = if cached_path.exists() {
        cached_path.clone()
    } else {
        bundled_path.to_path_buf()
    };
    println!("[TVDB][mapping] using path={}", path.display());

    let data = std::fs::read_to_string(&path)?;
    let entries: Vec<Value> = serde_json::from_str(&data)?;
    println!("[TVDB][mapping] loaded entries={}", entries.len());
    Ok(entries)
}

pub fn lookup_tvdb_match(
    mapping: &[Value],
    anilist_id: u32,
    format: Option<&str>,
) -> Result<TvdbMappingMatch, TvdbError> {
    let mut best_match: Option<(TvdbMappingMatch, i32)> = None;

    for entry in mapping {
        if entry["anilist_id"].as_u64() != Some(anilist_id as u64) {
            continue;
        }

        let Some(tvdb_id) = parse_tvdb_id(entry) else {
            continue;
        };

        let season_tvdb = parse_season_tvdb(entry);
        let entry_type = entry.get("type").and_then(|v| v.as_str());

        let mut score = 0;
        if let (Some(expected), Some(actual)) = (format, entry_type) {
            if expected.eq_ignore_ascii_case(actual) {
                score += 2;
            }
        }
        if season_tvdb.is_some() {
            score += 1;
        }

        let candidate = TvdbMappingMatch {
            tvdb_id,
            season_tvdb,
        };
        match best_match {
            Some((_, best_score)) if best_score >= score => {}
            _ => best_match = Some((candidate, score)),
        }
    }

    if let Some((m, _)) = best_match {
        println!(
            "[TVDB][mapping] lookup anilist_id={} format={:?} -> tvdb_id={} season_tvdb={:?}",
            anilist_id,
            format,
            m.tvdb_id,
            m.season_tvdb
        );
        return Ok(m);
    }

    eprintln!(
        "[TVDB][mapping] lookup failed anilist_id={} format={:?}",
        anilist_id,
        format
    );
    Err(TvdbError::MappingNotFound(anilist_id))
}

pub fn lookup_tvdb_id(mapping: &[Value], anilist_id: u32) -> Result<u64, TvdbError> {
    Ok(lookup_tvdb_match(mapping, anilist_id, None)?.tvdb_id)
}

fn parse_tvdb_id(entry: &Value) -> Option<u64> {
    entry
        .get("thetvdb_id")
        .and_then(|v| v.as_u64())
        .or_else(|| entry.get("tvdb_id").and_then(|v| v.as_u64()))
        .or_else(|| {
            entry
                .get("thetvdb_id")
                .and_then(|v| v.as_str())
                .and_then(|s| s.parse::<u64>().ok())
        })
        .or_else(|| {
            entry
                .get("tvdb_id")
                .and_then(|v| v.as_str())
                .and_then(|s| s.parse::<u64>().ok())
        })
}

fn parse_season_tvdb(entry: &Value) -> Option<u32> {
    entry
        .get("season")
        .and_then(|s| s.get("tvdb"))
        .and_then(|v| v.as_u64().map(|n| n as u32))
        .or_else(|| {
            entry
                .get("season")
                .and_then(|s| s.get("tvdb"))
                .and_then(|v| v.as_str())
                .and_then(|s| s.parse::<u32>().ok())
        })
}

fn should_update(cached_path: &PathBuf) -> bool {
    if !cached_path.exists() {
        return true;
    }
    match std::fs::metadata(cached_path)
        .and_then(|m| m.modified())
        .map(|t| t.elapsed().map(|d| d.as_secs() as i64).unwrap_or(i64::MAX))
    {
        Ok(age_secs) => age_secs > UPDATE_INTERVAL_SECONDS,
        Err(_) => true,
    }
}

async fn download_mapping(client: &Client, dest: &PathBuf) -> Result<(), TvdbError> {
    let bytes = client.get(MAPPING_URL).send().await?.bytes().await?;

    // validate it's valid JSON before overwriting
    serde_json::from_slice::<Vec<Value>>(&bytes).map_err(|e| TvdbError::Parse(e.to_string()))?;

    if let Some(parent) = dest.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(dest, &bytes)?;
    Ok(())
}