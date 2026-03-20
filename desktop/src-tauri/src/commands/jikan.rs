use namizo_core::{JikanClient, JikanEpisode};

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