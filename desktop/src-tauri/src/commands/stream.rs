use namizo_core::StreamSource;
use tauri::State;

use crate::state::AppState;

/// Fetch HLS stream sources for a given episode.
///
/// Called from the watch page when the user selects an episode.
/// The backend searches AnimePahe, obtains/refreshes the Cloudflare clearance
/// cookie via a hidden browser session, and returns ready-to-play sources.
#[tauri::command]
pub async fn get_episode_sources(
    anime_title: String,
    episode_num: f64,
    mode: String,
    state: State<'_, AppState>,
) -> Result<Vec<StreamSource>, String> {
    state
        .stream_service
        .get_episode_sources(&anime_title, episode_num, &mode)
        .await
        .map_err(|e| e.to_string())
}
