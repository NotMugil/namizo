import { invoke } from '@tauri-apps/api/core'
import type { StreamSource } from '$lib/types/stream'

interface PlaybackStartRaw {
    url: string
    kind: string
    session_id: string | null
    proxied: boolean
}

export interface PlaybackStartResult {
    url: string
    kind: string
    sessionId: string | null
    proxied: boolean
}

export async function playbackStart(source: StreamSource): Promise<PlaybackStartResult> {
    const raw = await invoke<PlaybackStartRaw>('playback_start', { source })
    return {
        url: raw.url,
        kind: raw.kind,
        sessionId: raw.session_id ?? null,
        proxied: raw.proxied,
    }
}

export async function playbackStop(sessionId?: string | null): Promise<void> {
    await invoke('playback_stop', { sessionId: sessionId ?? null })
}