use namizo_core::{AnimeService, PlaybackService, StreamService, TvdbService};

pub struct AppState {
    pub anime_service: AnimeService,
    pub stream_service: StreamService,
    pub playback_service: PlaybackService,
    pub tvdb_service: TvdbService,
}
