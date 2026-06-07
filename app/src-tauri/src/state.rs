use namizo_core::{AnimeService, LibraryService, PlaybackService, StreamService, TvdbService};

pub struct AppState {
    pub anime_service: AnimeService,
    pub library_service: LibraryService,
    pub playback_service: PlaybackService,
    pub stream_service: StreamService,
    pub tvdb_service: TvdbService,
}
