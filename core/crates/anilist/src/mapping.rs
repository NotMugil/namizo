use serde_json::Value;
use domain::anime::{AnimeDetails, AnimeSummary};
use crate::error::AnilistError;

pub fn to_summary_list(response: &Value) -> Result<Vec<AnimeSummary>, AnilistError> {
    let media_list = response["data"]["Page"]["media"]
        .as_array()
        .ok_or_else(|| AnilistError::Parse("missing media array".into()))?;

    Ok(media_list.iter().filter_map(to_summary).collect())
}

pub fn to_details(response: &Value) -> Result<AnimeDetails, AnilistError> {
    let m = &response["data"]["Media"];
    map_details(m).ok_or_else(|| AnilistError::Parse("failed to parse details".into()))
}

// ── private helpers ──────────────────────────────────────────────────────────

fn to_summary(m: &Value) -> Option<AnimeSummary> {
    Some(AnimeSummary {
        id:            m["id"].as_u64()? as u32,
        title:         resolve_title(m),
        cover_image:   m["coverImage"]["large"].as_str()?.to_string(),
        average_score: m["averageScore"].as_u64().map(|s| s as u8),
        genres:        str_array(&m["genres"]),
        format:        m["format"].as_str().map(|s| s.to_string()),
        episodes:      m["episodes"].as_u64().map(|e| e as u32),
    })
}

fn map_details(m: &Value) -> Option<AnimeDetails> {
    let trailer_id = if m["trailer"]["site"].as_str() == Some("youtube") {
        m["trailer"]["id"].as_str().map(|s| s.to_string())
    } else {
        None
    };

    let studios = m["studios"]["nodes"]
        .as_array()
        .map(|nodes| {
            nodes.iter()
                .filter_map(|n| n["name"].as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();

    Some(AnimeDetails {
        id:            m["id"].as_u64()? as u32,
        title:         resolve_title(m),
        cover_image:   m["coverImage"]["large"].as_str()?.to_string(),
        banner_image:  m["bannerImage"].as_str().map(|s| s.to_string()),
        description:   m["description"].as_str().map(|s| s.to_string()),
        genres:        str_array(&m["genres"]),
        average_score: m["averageScore"].as_u64().map(|s| s as u8),
        status:        m["status"].as_str().map(|s| s.to_string()),
        season:        m["season"].as_str().map(|s| s.to_string()),
        season_year:   m["seasonYear"].as_u64().map(|y| y as u32),
        format:        m["format"].as_str().map(|s| s.to_string()),
        episodes:      m["episodes"].as_u64().map(|e| e as u32),
        studios,
        trailer_id,
    })
}

fn resolve_title(m: &Value) -> String {
    m["title"]["english"]
        .as_str()
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| m["title"]["romaji"].as_str().unwrap_or("Unknown"))
        .to_string()
}

fn str_array(v: &Value) -> Vec<String> {
    v.as_array()
        .map(|arr| arr.iter().filter_map(|i| i.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default()
}