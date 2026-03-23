use crate::{AnilistClient, AnilistError};
use domain::{DiscoverFilters, DiscoverPage};
use serde_json::{json, Map, Value};

pub async fn fetch_discover(
    client: &AnilistClient,
    filters: &DiscoverFilters,
    page: u32,
    per_page: u8,
) -> Result<DiscoverPage, AnilistError> {
    let search = normalize_optional(filters.search.as_deref());
    let genres = normalize_list(&filters.genres);
    let formats = normalize_enum_list(&filters.formats);
    let sort = normalize_enum_list(&filters.sort);
    let status = normalize_enum_optional(filters.status.as_deref());
    let season = normalize_enum_optional(filters.season.as_deref());
    let page = page.max(1);
    let mut variables = Map::new();

    variables.insert("page".to_string(), json!(page));
    variables.insert("perPage".to_string(), json!(per_page));
    variables.insert(
        "sort".to_string(),
        json!(if sort.is_empty() {
            vec!["POPULARITY_DESC".to_string()]
        } else {
            sort
        }),
    );

    if let Some(value) = search {
        variables.insert("search".to_string(), json!(value));
    }
    if !genres.is_empty() {
        variables.insert("genreIn".to_string(), json!(genres));
    }
    if !formats.is_empty() {
        variables.insert("formatIn".to_string(), json!(formats));
    }
    if let Some(value) = status {
        variables.insert("status".to_string(), json!(value));
    }
    if let Some(value) = season {
        variables.insert("season".to_string(), json!(value));
    }
    if let Some(value) = filters.season_year {
        variables.insert("seasonYear".to_string(), json!(value));
    }
    if let Some(value) = filters.is_adult {
        variables.insert("isAdult".to_string(), json!(value));
    }

    client.fetch_media_page_with_info(Value::Object(variables)).await
}

fn normalize_list(values: &[String]) -> Vec<String> {
    values
        .iter()
        .filter_map(|value| {
            let trimmed = value.trim();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.to_string())
            }
        })
        .collect()
}

fn normalize_enum_list(values: &[String]) -> Vec<String> {
    values
        .iter()
        .filter_map(|value| normalize_enum_optional(Some(value.as_str())))
        .collect()
}

fn normalize_enum_optional(value: Option<&str>) -> Option<String> {
    let trimmed = value?.trim();
    if trimmed.is_empty() {
        return None;
    }

    Some(trimmed.replace('-', "_").replace(' ', "_").to_uppercase())
}

fn normalize_optional(value: Option<&str>) -> Option<String> {
    let trimmed = value?.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}