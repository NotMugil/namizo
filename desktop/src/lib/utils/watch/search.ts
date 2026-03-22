import type { ProviderKind } from '$lib/types/stream'

export function normalizeTitle(value: string): string {
    return value
        .toLowerCase()
        .replace(/['\u2019]/g, '')
        .replace(/[^a-z0-9]+/g, ' ')
        .trim()
}

export function inferSeasonIndex(...titles: Array<string | null | undefined>): number | null {
    for (const value of titles) {
        if (!value) continue
        const seasonMatch =
            value.match(/\bseason\s*(\d+)\b/i) ??
            value.match(/\b(\d+)(st|nd|rd|th)\s+season\b/i) ??
            value.match(/\bs(\d+)\b/i) ??
            value.match(/\bpart\s*(\d+)\b/i) ??
            value.match(/\b(\d+)(st|nd|rd|th)\s+part\b/i) ??
            value.match(/\u7b2c\s*(\d+)\s*\u671f/u)
        if (seasonMatch?.[1]) {
            const parsed = Number(seasonMatch[1])
            if (Number.isFinite(parsed) && parsed > 0) return parsed
        }

        const trailingNumeric = value.match(/\b(\d+)\b\s*$/)
        if (trailingNumeric?.[1]) {
            const parsed = Number(trailingNumeric[1])
            if (Number.isFinite(parsed) && parsed > 1 && parsed <= 20) return parsed
        }
    }
    return null
}

export function inferExplicitSeasonIndex(...titles: Array<string | null | undefined>): number | null {
    for (const value of titles) {
        if (!value) continue
        const seasonMatch =
            value.match(/\bseason\s*(\d+)\b/i) ??
            value.match(/\b(\d+)(st|nd|rd|th)\s+season\b/i) ??
            value.match(/\bs(\d+)\b/i) ??
            value.match(/\u7b2c\s*(\d+)\s*\u671f/u)
        if (seasonMatch?.[1]) {
            const parsed = Number(seasonMatch[1])
            if (Number.isFinite(parsed) && parsed > 0) return parsed
        }
    }
    return null
}

export function stripSeasonMarkers(value: string): string {
    return value
        .replace(/\bseason\s*\d+\b/gi, ' ')
        .replace(/\b\d+(st|nd|rd|th)\s+season\b/gi, ' ')
        .replace(/\bpart\s*\d+\b/gi, ' ')
        .replace(/\bcour\s*\d+\b/gi, ' ')
        .replace(/\u7b2c\s*\d+\s*\u671f/g, ' ')
        .replace(/[\-:()]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
}

export function buildSearchQueries(
    base: string,
    targetProvider: ProviderKind,
    context: {
        detailsTitle?: string | null
        detailsTitleJapanese?: string | null
        relationTitles?: string[]
    },
): string[] {
    const detailsTitle = context.detailsTitle ?? ''
    const detailsTitleJapanese = context.detailsTitleJapanese ?? ''
    const relationTitles = context.relationTitles ?? []
    const desiredSeasonIndex = inferSeasonIndex(base, detailsTitle, detailsTitleJapanese)
    const candidates = [base, detailsTitle, detailsTitleJapanese, ...relationTitles]

    if (targetProvider === 'animepahe' && Number.isFinite(desiredSeasonIndex) && (desiredSeasonIndex ?? 1) > 1) {
        const baseTitle = stripSeasonMarkers(detailsTitle || base)
        if (baseTitle) {
            candidates.push(`${baseTitle} ${desiredSeasonIndex}`)
            candidates.push(`${baseTitle} season ${desiredSeasonIndex}`)
        }
    }

    const seen = new Set<string>()
    const out: string[] = []

    for (const raw of candidates) {
        const value = raw.trim()
        const stripped = stripSeasonMarkers(value)
        for (const candidate of [value, stripped]) {
            if (!candidate) continue
            const key = candidate.toLowerCase()
            if (seen.has(key)) continue
            seen.add(key)
            out.push(candidate)
        }
    }

    return out
}