import type { ProviderKind, StreamSource } from '$lib/types/stream'
import { parseEpisodeNumber } from './episodes'

type ProviderOption = { label: string; value: ProviderKind }

export function providerName(value: ProviderKind, providerOptions: ProviderOption[]): string {
    return providerOptions.find(option => option.value === value)?.label ?? value
}

export function sourceReliabilityScore(source: StreamSource): number {
    let score = 0
    const normalizedKind = source.kind.toLowerCase()
    const normalizedQuality = source.quality.toLowerCase()

    if (normalizedKind.includes('mp4')) score += 1000
    if (normalizedKind.includes('hls')) score += 500

    const qualityValue = parseEpisodeNumber(source.quality)
    if (Number.isFinite(qualityValue)) {
        score += Math.max(0, 400 - Math.abs(qualityValue - 720))
        if (qualityValue > 900) score -= normalizedKind.includes('hls') ? 200 : 60
    }

    if (normalizedQuality.includes('auto')) score += 40
    return score
}

export function pickBestSource(pool: StreamSource[]): StreamSource | null {
    if (pool.length === 0) return null
    return [...pool].sort((a, b) => sourceReliabilityScore(b) - sourceReliabilityScore(a))[0] ?? null
}

export function orderSources(pool: StreamSource[]): StreamSource[] {
    const best = pickBestSource(pool)
    if (!best) return []
    return [best, ...pool.filter(source => source.url !== best.url)]
}

export function formatSourceLabel(source: StreamSource | null): string {
    if (!source) return 'none'
    return `${source.quality}/${source.kind}`
}

export function buildPlaybackFailureMessage(params: {
    stage: string
    reason: string
    provider: ProviderKind
    providerOptions: ProviderOption[]
    selectedNumber: number
    selectedSource: StreamSource | null
}): string {
    return [
        `Playback failed at ${params.stage}.`,
        `Provider: ${providerName(params.provider, params.providerOptions)}`,
        `Episode: ${params.selectedNumber}`,
        `Source: ${formatSourceLabel(params.selectedSource)}`,
        `Reason: ${params.reason}`,
    ].join(' ')
}