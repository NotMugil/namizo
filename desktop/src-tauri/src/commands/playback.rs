use namizo_core::{PlaybackStart, StreamSource};
use tauri::State;

use crate::state::AppState;

#[tauri::command]
pub async fn playback_start(
    source: StreamSource,
    state: State<'_, AppState>,
) -> Result<PlaybackStart, String> {
Ok(state.playback_service.start(source).await)
}

#[tauri::command]
pub async fn playback_stop(
    session_id: Option<String>,
    state: State<'_, AppState>,
) -> Result<(), String> {
state.playback_service.stop(session_id.as_deref()).await;
    Ok(())
}