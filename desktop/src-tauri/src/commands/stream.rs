use tauri::State;
use namizo_core::{StreamingEpisode, SourceOptions, StreamSource, StreamableAnime};
use crate::state::AppState;

#[tauri::command]
pub async fn stream_search(
    provider: String,
    query: String,
    state: State<'_, AppState>,
) -> Result<Vec<StreamableAnime>, String> {
    eprintln!(
        "[tauri:stream_search] provider={} query={:?}",
        provider, query
    );
    match state.stream_service.search(&provider, &query).await {
        Ok(results) => {
            eprintln!(
                "[tauri:stream_search] provider={} results={}",
                provider,
                results.len()
            );
            Ok(results)
        }
        Err(error) => {
            eprintln!("[tauri:stream_search] provider={} error={}", provider, error);
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
    eprintln!(
        "[tauri:stream_episodes] provider={} anime_id={} title={:?}",
        provider, anime.id, anime.title
    );
    match state.stream_service.episodes(&provider, &anime).await {
        Ok(episodes) => {
            eprintln!(
                "[tauri:stream_episodes] provider={} anime_id={} episodes={}",
                provider,
                anime.id,
                episodes.len()
            );
            Ok(episodes)
        }
        Err(error) => {
            eprintln!(
                "[tauri:stream_episodes] provider={} anime_id={} error={}",
                provider, anime.id, error
            );
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
    eprintln!(
        "[tauri:stream_sources] provider={} anime_id={} episode={} source_id={:?} options={:?}",
        provider, episode.anime_id, episode.number, episode.source_id, options
    );
    match state.stream_service.sources(&provider, &episode, options).await {
        Ok(sources) => {
            eprintln!(
                "[tauri:stream_sources] provider={} anime_id={} episode={} sources={}",
                provider,
                episode.anime_id,
                episode.number,
                sources.len()
            );
            Ok(sources)
        }
        Err(error) => {
            eprintln!(
                "[tauri:stream_sources] provider={} anime_id={} episode={} error={}",
                provider, episode.anime_id, episode.number, error
            );
            Err(error)
        }
    }
}