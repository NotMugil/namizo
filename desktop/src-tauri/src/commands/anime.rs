use crate::state::AppState;
use namizo_core::{AnimeDetails, AnimeSummary, DiscoverFilters, DiscoverPage};
use std::collections::HashMap;
use tauri::State;

#[tauri::command]
pub async fn get_trending(state: State<'_, AppState>) -> Result<Vec<AnimeSummary>, String> {
    state.anime_service.trending(20).await
}

#[tauri::command]
pub async fn get_popular(
    per_page: Option<u8>,
    state: State<'_, AppState>,
) -> Result<Vec<AnimeSummary>, String> {
    state.anime_service.popular(per_page.unwrap_or(20)).await
}

#[tauri::command]
pub async fn get_top_rated(state: State<'_, AppState>) -> Result<Vec<AnimeSummary>, String> {
    state.anime_service.top_rated(20).await
}

#[tauri::command]
pub async fn get_home_genres(
    genres: Vec<String>,
    state: State<'_, AppState>,
) -> Result<HashMap<String, Vec<AnimeSummary>>, String> {
    state.anime_service.genres_batch(genres).await
}

#[tauri::command]
pub async fn get_anime_details(
    id: u32,
    state: State<'_, AppState>,
) -> Result<AnimeDetails, String> {
    state.anime_service.details(id).await
}

#[tauri::command]
pub async fn search_anime(
    query: String,
    per_page: Option<u8>,
    state: State<'_, AppState>,
) -> Result<Vec<AnimeSummary>, String> {
    state.anime_service.search(&query, per_page.unwrap_or(30)).await
}

#[tauri::command]
pub async fn discover_anime(
    filters: Option<DiscoverFilters>,
    page: Option<u32>,
    per_page: Option<u8>,
    state: State<'_, AppState>,
) -> Result<DiscoverPage, String> {
    state
        .anime_service
        .discover(filters.unwrap_or_default(), page.unwrap_or(1), per_page.unwrap_or(24))
        .await
}