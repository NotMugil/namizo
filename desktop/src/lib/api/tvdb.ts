import { invoke } from '@tauri-apps/api/core'
import type { TvdbEpisode } from '$lib/types/tvdb'

export async function getTvdbEpisodes(
    anilistId: number,
    format: string | null
): Promise<TvdbEpisode[]> {
    console.log('[TVDB][ui] invoke get_tvdb_episodes', {
        anilistId,
        format,
    })

    const result = await invoke<TvdbEpisode[]>('get_tvdb_episodes', {
        anilistId,
        format,
    })

    console.log('[TVDB][ui] invoke success get_tvdb_episodes', {
        anilistId,
        episodes: result.length,
    })

    return result
}