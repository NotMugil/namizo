use serde_json::Value;
use domain::{AnimeDetails, AnimeSummary, Character, DiscoverPage, Episode};
use crate::error::AnilistError;

pub fn to_summary_list(response: &Value) -> Result<Vec<AnimeSummary>, AnilistError> {
    if let Some(error) = response_error_message(response) {
        return Err(AnilistError::Parse(error));
    }

    let media_list = response["data"]["Page"]["media"]
        .as_array()
        .ok_or_else(|| AnilistError::Parse("missing media array".into()))?;

    Ok(media_list.iter().filter_map(to_summary).collect())
}

pub fn to_details(response: &Value) -> Result<AnimeDetails, AnilistError> {
    if let Some(error) = response_error_message(response) {
        return Err(AnilistError::Parse(error));
    }

    let m = &response["data"]["Media"];
    map_details(m).ok_or_else(|| AnilistError::Parse("failed to parse details".into()))
}

pub fn to_discover_page(response: &Value) -> Result<DiscoverPage, AnilistError> {
    if let Some(error) = response_error_message(response) {
        return Err(AnilistError::Parse(error));
    }

    let page = &response["data"]["Page"];
    let media_list = page["media"]
        .as_array()
        .ok_or_else(|| AnilistError::Parse("missing media array".into()))?;
    let page_info = &page["pageInfo"];

    Ok(DiscoverPage {
        items: media_list.iter().filter_map(to_summary).collect(),
        current_page: page_info["currentPage"].as_u64().unwrap_or(1) as u32,
        has_next_page: page_info["hasNextPage"].as_bool().unwrap_or(false),
        total: page_info["total"].as_u64().map(|v| v as u32),
        last_page: page_info["lastPage"].as_u64().map(|v| v as u32),
        per_page: page_info["perPage"].as_u64().map(|v| v as u32),
    })
}

fn response_error_message(response: &Value) -> Option<String> {
    let errors = response["errors"].as_array()?;
    if errors.is_empty() {
        return None;
    }

    let messages = errors
        .iter()
        .filter_map(|entry| entry["message"].as_str())
        .map(|message| message.trim())
        .filter(|message| !message.is_empty())
        .collect::<Vec<_>>();

    if messages.is_empty() {
        Some("AniList GraphQL request failed.".to_string())
    } else {
        Some(messages.join(" | "))
    }
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

fn map_character(edge: &Value) -> Option<Character> {
    let node = &edge["node"];
    Some(Character {
        id:    node["id"].as_u64()? as u32,
        name:  node["name"]["full"].as_str()?.to_string(),
        image: node["image"]["large"].as_str().map(|s| s.to_string()),
        role:  edge["role"].as_str().unwrap_or("SUPPORTING").to_string(),
    })
}

// private helpers

fn to_summary(m: &Value) -> Option<AnimeSummary> {
    let trailer_id = if m["trailer"]["site"].as_str() == Some("youtube") {
        m["trailer"]["id"].as_str().map(|s| s.to_string())
    } else {
        None
    };

    Some(AnimeSummary {
        id:            m["id"].as_u64()? as u32,
        title:         resolve_title(m),
        cover_image:   m["coverImage"]["large"].as_str()?.to_string(),
        description:   m["description"].as_str().map(|s| s.to_string()),
        average_score: m["averageScore"].as_u64().map(|s| s as u8),
        genres:        str_array(&m["genres"]),
        format:        m["format"].as_str().map(|s| s.to_string()),
        episodes:      m["episodes"].as_u64().map(|e| e as u32),
        banner_image: m["bannerImage"].as_str().map(|s| s.to_string()),
        trailer_id,
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

        let characters = m["characters"]["edges"]
        .as_array()
        .map(|edges| edges.iter().filter_map(map_character).collect())
        .unwrap_or_default();

    let relations = m["relations"]["edges"]
        .as_array()
        .map(|edges| {
            edges.iter()
                .filter_map(|e| {
                    // skip manga/novel relations
                    let kind = e["node"]["type"].as_str().unwrap_or("");
                    if kind != "ANIME" { return None; }
                    to_summary(&e["node"])
                })
                .collect()
        })
        .unwrap_or_default();

    let recommendations = m["recommendations"]["nodes"]
        .as_array()
        .map(|nodes| {
            nodes.iter()
                .filter_map(|n| to_summary(&n["mediaRecommendation"]))
                .collect()
        })
        .unwrap_or_default();
    
    let episodes: Vec<Episode> = (1..=m["episodes"].as_u64().unwrap_or(0) as u32)
        .map(|n| Episode { number: n, title: None, thumbnail: None, description: None })
        .collect();


    Some(AnimeDetails {
        id:            m["id"].as_u64()? as u32,
        id_mal: m["idMal"].as_u64().map(|v| v as u32),
        title:         resolve_title(m),
        title_japanese: m["title"]["native"].as_str().map(|s| s.to_string()),
        cover_image:   m["coverImage"]["large"].as_str()?.to_string(),
        banner_image:  m["bannerImage"].as_str().map(|s| s.to_string()),
        description:   m["description"].as_str().map(|s| s.to_string()),
        genres:        str_array(&m["genres"]),
        average_score: m["averageScore"].as_u64().map(|s| s as u8),
        status:        m["status"].as_str().map(|s| s.to_string()),
        season:        m["season"].as_str().map(|s| s.to_string()),
        season_year:   m["seasonYear"].as_u64().map(|y| y as u32),
        format:        m["format"].as_str().map(|s| s.to_string()),
        episode_count: m["episodes"].as_u64().map(|e| e as u32),
        studios,
        trailer_id,
        characters,
        relations,
        recommendations,
        episodes,
    })
}