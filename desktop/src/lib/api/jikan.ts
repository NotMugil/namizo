import { invoke } from '@tauri-apps/api/core'
import type { JikanEpisode, JikanEpisodesPage } from '$lib/types/jikan'

export async function getJikanEpisodes(malId: number): Promise<JikanEpisode[]> {
    return invoke('get_jikan_episodes', { malId })
}

export async function getJikanEpisodesPage(malId: number, page: number): Promise<JikanEpisodesPage> {
    return invoke('get_jikan_episodes_page', { malId, page })
}