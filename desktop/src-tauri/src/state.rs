use namizo_core::{AnimeService, LibraryService, PlaybackService, StreamService, TvdbService};

pub struct AppState {
    pub anime_service: AnimeService,
    pub library_service: LibraryService,
    pub stream_service: StreamService,
    pub playback_service: PlaybackService,
    pub tvdb_service: TvdbService,
}