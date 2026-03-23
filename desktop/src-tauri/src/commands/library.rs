use crate::state::AppState;
use namizo_core::{LibraryFacets, ShelfEntry, ShelfState};
use tauri::State;

#[tauri::command]
pub async fn library_fetch(
    state: Option<ShelfState>,
    app_state: State<'_, AppState>,
) -> Result<Vec<ShelfEntry>, String> {
    app_state.library_service.fetch(state).await
}

#[tauri::command]
pub async fn library_save(
    entry: ShelfEntry,
    app_state: State<'_, AppState>,
) -> Result<ShelfEntry, String> {
    app_state.library_service.save(entry).await
}

#[tauri::command]
pub async fn library_remove(
    anilist_id: u32,
    app_state: State<'_, AppState>,
) -> Result<(), String> {
    app_state.library_service.remove(anilist_id).await
}

#[tauri::command]
pub async fn library_progress(
    anilist_id: u32,
    episode: u32,
    percent: u8,
    app_state: State<'_, AppState>,
) -> Result<(), String> {
    app_state
        .library_service
        .progress(anilist_id, episode, percent)
        .await
}

#[tauri::command]
pub async fn library_resume(app_state: State<'_, AppState>) -> Result<Vec<ShelfEntry>, String> {
    app_state.library_service.resume().await
}

#[tauri::command]
pub async fn library_facets(app_state: State<'_, AppState>) -> Result<LibraryFacets, String> {
    app_state.library_service.facets().await
}