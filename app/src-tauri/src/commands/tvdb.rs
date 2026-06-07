use crate::state::AppState;
use namizo_core::TvdbEpisode;
use tauri::State;

#[tauri::command]
pub async fn get_tvdb_episodes(
    anilist_id: u32,
    format: Option<String>,
    state: State<'_, AppState>,
) -> Result<Vec<TvdbEpisode>, String> {
    state
        .tvdb_service
        .get_episodes(anilist_id, format.as_deref())
        .await
}

#[tauri::command]
pub async fn get_tvdb_background(
    anilist_id: u32,
    format: Option<String>,
    state: State<'_, AppState>,
) -> Result<Option<String>, String> {
    state
        .tvdb_service
        .get_background(anilist_id, format.as_deref())
        .await
}

#[tauri::command]
pub async fn get_tvdb_clear_logo(
    anilist_id: u32,
    format: Option<String>,
    state: State<'_, AppState>,
) -> Result<Option<String>, String> {
    state
        .tvdb_service
        .get_clear_logo(anilist_id, format.as_deref())
        .await
}

#[tauri::command]
pub async fn clear_tvdb_cache(state: State<'_, AppState>) -> Result<(), String> {
    state.tvdb_service.clear_cache()
}