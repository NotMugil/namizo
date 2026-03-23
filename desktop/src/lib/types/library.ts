export type LibraryState =
    | "WATCHING"
    | "PLANNING"
    | "COMPLETED"
    | "REWATCHING"
    | "DROPPED"
    | "PAUSED";

export type LibraryListScope = "ALL" | LibraryState;

export type LibrarySortValue =
    | "A_Z"
    | "Z_A"
    | "POPULARITY_DESC"
    | "POPULARITY_ASC"
    | "USER_SCORE_DESC"
    | "USER_SCORE_ASC"
    | "RATING_DESC"
    | "RATING_ASC"
    | "PROGRESS_DESC"
    | "PROGRESS_ASC"
    | "OLDEST"
    | "NEWEST";

export type LibraryReleaseFilter = "ALL" | "FINISHED" | "RELEASING" | "NOT_YET_RELEASED";
export type KnownLibraryReleaseStatus = Exclude<LibraryReleaseFilter, "ALL">;

export interface LibrarySectionDef {
    value: LibraryState;
    label: string;
    dotClass: string;
}

export interface LibraryEntry {
    anilist_id: number;
    title: string;
    cover_image: string | null;
    banner_image: string | null;
    format: string | null;
    episode_total: number | null;
    score: number | null;
    genres: string[];
    anilist_status: string | null;
    season: string | null;
    season_year: number | null;
    popularity: number | null;
    average_score: number | null;
    start_date: string | null;
    end_date: string | null;
    rewatches: number;
    notes: string | null;
    status: LibraryState;
    progress: number;
    progress_percent: number;
    last_episode: number | null;
    last_watched_at: number | null;
    created_at: number;
    updated_at: number;
}

export interface LibraryFacets {
    genres: string[];
    release_statuses: string[];
    seasons: string[];
    years: number[];
}