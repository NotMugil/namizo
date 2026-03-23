use tauri::State;
use namizo_core::{StreamingEpisode, SourceOptions, StreamSource, StreamableAnime};
use crate::state::AppState;

#[tauri::command]
pub async fn stream_search(
    provider: String,
    query: String,
    state: State<'_, AppState>,
) -> Result<Vec<StreamableAnime>, String> {
match state.stream_service.search(&provider, &query).await {
        Ok(results) => {
Ok(results)
        }
        Err(error) => {
Err(error)
        }
    }
}

#[tauri::command]
pub async fn stream_episodes(
    provider: String,
    anime: StreamableAnime,
    state: State<'_, AppState>,
) -> Result<Vec<StreamingEpisode>, String> {
match state.stream_service.episodes(&provider, &anime).await {
        Ok(episodes) => {
Ok(episodes)
        }
        Err(error) => {
Err(error)
        }
    }
}

#[tauri::command]
pub async fn stream_sources(
    provider: String,
    episode: StreamingEpisode,
    options: Option<SourceOptions>,
    state: State<'_, AppState>,
) -> Result<Vec<StreamSource>, String> {
match state.stream_service.sources(&provider, &episode, options).await {
        Ok(sources) => {
Ok(sources)
        }
        Err(error) => {
Err(error)
        }
    }
}