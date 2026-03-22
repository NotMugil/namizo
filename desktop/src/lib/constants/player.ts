import type { HlsConfig } from 'hls.js'

export const FULLSCREEN_UI_HIDE_DELAY_MS = 2600
export const HLS_RECOVERY_COOLDOWN_MS = 1200
export const HLS_RECOVERY_WINDOW_MS = 16_000
export const HLS_MAX_RECOVERY_ATTEMPTS = 5
export const FRAG_PARSING_WINDOW_MS = 8_000
export const FRAG_PARSING_RECOVER_THRESHOLD = 3

export const HLS_PLAYER_CONFIG: Partial<HlsConfig> = {
    lowLatencyMode: false,
    autoStartLoad: true,
    startFragPrefetch: true,
    defaultAudioCodec: 'mp4a.40.2',
    maxBufferHole: 1,
    nudgeOffset: 0.2,
    nudgeMaxRetry: 10,
    maxFragLookUpTolerance: 0.5,
}