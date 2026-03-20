use namizo_core::{AnimeService, StreamService};

pub struct AppState {
    pub anime_service: AnimeService,
    pub stream_service: StreamService,
}