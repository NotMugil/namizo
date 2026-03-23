export interface AnimeSummary {
    id: number
    title: string
    cover_image: string
    description: string | null
    average_score: number | null
    genres: string[]
    format: string | null
    episodes: number | null
    banner_image: string | null
    trailer_id: string | null
    status?: string | null
    next_airing_episode?: number | null
    next_airing_at?: number | null
}

export interface DiscoverFilters {
    search?: string | null
    genres?: string[]
    formats?: string[]
    status?: string | null
    season?: string | null
    season_year?: number | null
    sort?: string[]
    is_adult?: boolean | null
}

export interface DiscoverPage {
    items: AnimeSummary[]
    current_page: number
    has_next_page: boolean
    total: number | null
    last_page: number | null
    per_page: number | null
}

export interface AnimeDetails {
    id: number
    id_mal: number | null
    title: string
    title_japanese: string | null
    cover_image: string
    banner_image: string | null
    description: string | null
    genres: string[]
    average_score: number | null
    popularity: number | null
    status: string | null
    season: string | null
    season_year: number | null
    format: string | null
    episode_count: number | null
    studios: string[]
    trailer_id: string | null
    characters: Character[]
    relations: AnimeSummary[]
    recommendations: AnimeSummary[]
    episodes: Episode[]
}

export interface Character {
    id: number
    name: string
    image: string | null
    role: string
}

export interface Episode {
    number: number
    title: string | null
    thumbnail: string | null
    description: string | null
}