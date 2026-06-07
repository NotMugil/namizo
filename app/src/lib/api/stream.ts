import { invoke } from '@tauri-apps/api/core'
import type { StreamSource } from '$lib/types/stream'

/**
 * Ask the Rust backend for HLS sources for a specific episode.
 * The backend searches AnimePahe, acquires a Cloudflare clearance cookie
 * via a hidden browser session, and returns ready-to-play sources.
 */
export async function getEpisodeSources(
    animeTitle: string,
    episodeNum: number,
    mode: 'sub' | 'dub' = 'sub',
): Promise<StreamSource[]> {
    return invoke<StreamSource[]>('get_episode_sources', {
        animeTitle,
        episodeNum,
        mode,
    })
}
