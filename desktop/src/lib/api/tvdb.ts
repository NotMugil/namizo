import { invoke } from '@tauri-apps/api/core'
import type { TvdbEpisode } from '$lib/types/tvdb'

export async function getTvdbEpisodes(
    anilistId: number,
    format: string | null
): Promise<TvdbEpisode[]> {
    return invoke<TvdbEpisode[]>('get_tvdb_episodes', {
        anilistId,
        format,
    })
}

export async function getTvdbBackground(
    anilistId: number,
    format: string | null
): Promise<string | null> {
    return invoke<string | null>('get_tvdb_background', {
        anilistId,
        format,
    })
}