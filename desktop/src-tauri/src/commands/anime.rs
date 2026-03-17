use std::collections::HashMap;
use tauri::State;
use namizo_core::{AnimeDetails, AnimeSummary};
use crate::state::AppState;

#[tauri::command]
pub async fn get_trending(state: State<'_, AppState>) -> Result<Vec<AnimeSummary>, String> {
    state.anime_service.trending(20).await
}

#[tauri::command]
pub async fn get_popular(state: State<'_, AppState>) -> Result<Vec<AnimeSummary>, String> {
    state.anime_service.popular(20).await
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