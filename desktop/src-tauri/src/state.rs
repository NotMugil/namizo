use namizo_core::{AnimeService, StreamService, TvdbService};

pub struct AppState {
    pub anime_service: AnimeService,
    pub stream_service: StreamService,
    pub tvdb_service: TvdbService,
}