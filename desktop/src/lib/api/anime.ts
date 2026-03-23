import { invoke } from '@tauri-apps/api/core'
import type { AnimeSummary, AnimeDetails, DiscoverFilters, DiscoverPage } from '$lib/types/anime'

export const HOME_GENRES = ['Action', 'Adventure', 'Romance', 'Fantasy', 'Comedy']

export async function getTrending(): Promise<AnimeSummary[]> {
    return invoke('get_trending')
}

export async function getPopular(perPage = 20): Promise<AnimeSummary[]> {
    return invoke('get_popular', { perPage })
}

export async function getTopRated(): Promise<AnimeSummary[]> {
    return invoke('get_top_rated')
}

export async function getHomeGenres(): Promise<Record<string, AnimeSummary[]>> {
    return invoke('get_home_genres', { genres: HOME_GENRES })
}

export async function getAnimeDetails(id: number): Promise<AnimeDetails> {
    return invoke('get_anime_details', { id })
}

export async function searchAnime(query: string, perPage = 30): Promise<AnimeSummary[]> {
    return invoke('search_anime', { query, perPage })
}

export async function discoverAnime(
    filters: DiscoverFilters = {},
    page = 1,
    perPage = 24,
): Promise<DiscoverPage> {
    return invoke('discover_anime', { filters, page, perPage })
}