import { invoke } from '@tauri-apps/api/core'
import type { StreamableAnime, StreamSource, StreamingEpisode } from '$lib/types/stream'

export async function streamSearch(
    provider: string,
    query: string
): Promise<StreamableAnime[]> {
    return invoke('stream_search', { provider, query })
}

export async function streamEpisodes(
    provider: string,
    anime: StreamableAnime
): Promise<StreamingEpisode[]> {
    return invoke('stream_episodes', { provider, anime })
}

export async function streamSources(
    provider: string,
    episode: StreamingEpisode,
    options?: { mode?: string; host?: string } | null
): Promise<StreamSource[]> {
    return invoke('stream_sources', { provider, episode, options })
}