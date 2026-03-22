use namizo_core::{JikanClient, JikanEpisode, JikanEpisodesPage};

#[tauri::command]
pub async fn get_jikan_episodes(
    mal_id: u32,
) -> Result<Vec<JikanEpisode>, String> {
    let result = JikanClient::new()
        .get_episodes(mal_id)
        .await;

    match result {
        Ok(data) => Ok(data),
        Err(e) => Err(e.to_string()),
    }
}

#[tauri::command]
pub async fn get_jikan_episodes_page(
    mal_id: u32,
    page: u32,
) -> Result<JikanEpisodesPage, String> {
    let result = JikanClient::new()
        .get_episodes_page(mal_id, page)
        .await;

    match result {
        Ok(data) => Ok(data),
        Err(e) => Err(e.to_string()),
    }
}
