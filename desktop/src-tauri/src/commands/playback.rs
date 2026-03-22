use namizo_core::{PlaybackStart, StreamSource};
use tauri::State;

use crate::state::AppState;

#[tauri::command]
pub async fn playback_start(
    source: StreamSource,
    state: State<'_, AppState>,
) -> Result<PlaybackStart, String> {
    eprintln!(
        "[tauri:playback_start] kind={} quality={} url={} headers={:?}",
        source.kind, source.quality, source.url, source.headers
    );
    Ok(state.playback_service.start(source).await)
}

#[tauri::command]
pub async fn playback_stop(
    session_id: Option<String>,
    state: State<'_, AppState>,
) -> Result<(), String> {
    eprintln!("[tauri:playback_stop] session_id={:?}", session_id);
    state.playback_service.stop(session_id.as_deref()).await;
    Ok(())
}
