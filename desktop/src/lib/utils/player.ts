export function pathIsHls(url: string, kind: string): boolean {
    const normalizedKind = kind.toLowerCase()
    const normalizedUrl = url.toLowerCase()
    return normalizedKind.includes('hls') || normalizedUrl.includes('.m3u8')
}

export function normalizeAudioCodec(codec: string | undefined): string | undefined {
    if (!codec) return undefined
    const normalized = codec.trim()
    if (normalized.toLowerCase() === 'mp4a.40.1') return 'mp4a.40.2'
    return normalized
}

export function firstSupportedHlsLevel(levels: Array<{ videoCodec?: string; audioCodec?: string }>): number | null {
    if (levels.length === 0) return null
    if (typeof window === 'undefined' || !window.MediaSource?.isTypeSupported) return 0

    for (let index = 0; index < levels.length; index += 1) {
        const level = levels[index]
        const videoCodec = level.videoCodec?.trim()
        const audioCodec = normalizeAudioCodec(level.audioCodec)
        if (!videoCodec && !audioCodec) return index

        const videoSupported = videoCodec
            ? window.MediaSource.isTypeSupported(`video/mp4; codecs="${videoCodec}"`)
            : true
        const audioSupported = audioCodec
            ? window.MediaSource.isTypeSupported(`audio/mp4; codecs="${audioCodec}"`)
            : true
        if (videoSupported && audioSupported) return index
    }

    return null
}

export function describeVideoErrorCode(code: number | undefined): string {
    if (!code) return 'unknown'
    if (code === 1) return 'aborted'
    if (code === 2) return 'network'
    if (code === 3) return 'decode'
    if (code === 4) return 'src_not_supported'
    return String(code)
}

export function formatPlaybackTime(totalSeconds: number): string {
    if (!Number.isFinite(totalSeconds) || totalSeconds <= 0) return '00:00'
    const absolute = Math.max(0, Math.floor(totalSeconds))
    const hours = Math.floor(absolute / 3600)
    const minutes = Math.floor((absolute % 3600) / 60)
    const seconds = absolute % 60
    if (hours > 0) return `${hours}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}