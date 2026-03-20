import { invoke } from '@tauri-apps/api/core'
import type { JikanEpisode } from '$lib/types/jikan'

export async function getJikanEpisodes(malId: number): Promise<JikanEpisode[]> {
    return invoke('get_jikan_episodes', { malId })
}