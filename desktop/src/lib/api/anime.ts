import { invoke } from '@tauri-apps/api/core'
import type { AnimeSummary, AnimeDetails } from '$lib/types/anime'

export const HOME_GENRES = ['Action', 'Adventure', 'Romance', 'Fantasy', 'Comedy']

export async function getTrending(): Promise<AnimeSummary[]> {
    return invoke('get_trending')
}

export async function getPopular(): Promise<AnimeSummary[]> {
    return invoke('get_popular')
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