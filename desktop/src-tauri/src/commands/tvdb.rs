use tauri::State;
use namizo_core::TvdbEpisode;
use crate::state::AppState;

#[tauri::command]
pub async fn get_tvdb_episodes(
    anilist_id: u32,
    format: Option<String>,
    state: State<'_, AppState>,
) -> Result<Vec<TvdbEpisode>, String> {
    println!(
        "[TVDB][command] get_tvdb_episodes anilist_id={} format={:?}",
        anilist_id, format
    );

    let result = state.tvdb_service
        .get_episodes(anilist_id, format.as_deref())
        .await;

    match &result {
        Ok(episodes) => println!(
            "[TVDB][command] success anilist_id={} episodes={}",
            anilist_id,
            episodes.len()
        ),
        Err(err) => eprintln!(
            "[TVDB][command] failure anilist_id={} err={}",
            anilist_id,
            err
        ),
    }

    result
}
