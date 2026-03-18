export interface AnimeSummary {
    id: number
    title: string
    cover_image: string
    average_score: number | null
    genres: string[]
    format: string | null
    episodes: number | null
}

export interface AnimeDetails {
    id: number
    title: string
    title_japanese: string | null
    cover_image: string
    banner_image: string | null
    description: string | null
    genres: string[]
    average_score: number | null
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