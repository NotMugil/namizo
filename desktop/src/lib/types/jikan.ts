export interface JikanEpisode {
    number: number
    mal_id: number
    title: string | null
    filler: boolean
    recap: boolean
}

export interface JikanEpisodesPage {
    page: number
    has_next_page: boolean
    total_episodes: number | null
    episodes: JikanEpisode[]
}