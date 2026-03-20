#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod state;

use namizo_core::{AnimeService, StreamService};
use state::AppState;

fn main() {
    tauri::Builder::default()
        .manage(AppState {
            anime_service: AnimeService::new(),
            stream_service: StreamService::new(),
        })
        .invoke_handler(tauri::generate_handler![
            commands::anime::get_trending,
            commands::anime::get_popular,
            commands::anime::get_top_rated,
            commands::anime::get_home_genres,
            commands::anime::get_anime_details,
            commands::stream::stream_search,
            commands::stream::stream_episodes,
            commands::stream::stream_sources,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}