#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod state;

use std::path::PathBuf;

use namizo_core::{AnimeService, StreamService, TvdbService};
use state::AppState;
use tauri::Manager;

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            tauri::async_runtime::block_on(async {
                let app_data_dir = dirs::data_dir()
                    .unwrap_or_else(|| PathBuf::from("."))
                    .join("namizo");

                std::fs::create_dir_all(&app_data_dir).ok();

                let db_path = app_data_dir.join("namizo.db");
                let bundled_mapping = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                    .join("resources/anime-list-full.json");

                let tvdb_api_key = std::env::var("TVDB_API_KEY")
                    .unwrap_or_else(|_| "57a0987f38d45bs3acf0f84ffee71196".into());

                let tvdb_service = TvdbService::new(
                    &tvdb_api_key,
                    &db_path,
                    &app_data_dir,
                    &bundled_mapping,
                )
                .await
                .expect("failed to init tvdb service");

                app.manage(AppState {
                    anime_service: AnimeService::new(),
                    stream_service: StreamService::new(),
                    tvdb_service,
                });
            });

            Ok(())
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
            commands::jikan::get_jikan_episodes,
            commands::tvdb::get_tvdb_episodes,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}