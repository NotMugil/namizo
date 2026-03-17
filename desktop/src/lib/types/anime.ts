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
    cover_image: string
    banner_image: string | null
    description: string | null
    genres: string[]
    average_score: number | null
    status: string | null
    season: string | null
    season_year: number | null
    format: string | null
    episodes: number | null
    studios: string[]
    trailer_id: string | null
}