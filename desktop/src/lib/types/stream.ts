export interface StreamableAnime {
    id: string
    title: string
    available_episodes: number | null
    season?: string | null
    year?: number | null
    media_type?: string | null
    status?: string | null
}

export interface StreamingEpisode {
    anime_id: string
    number: string
    source_id: string | null
}

export interface StreamSource {
    url: string
    quality: string
    kind: string
    headers: Record<string, string> | null
}

export type ProviderKind = 'animepahe' | 'allanime' | 'anizone' | 'anidap'

export interface SourceOptions {
    mode?: string | null
    host?: string | null
}