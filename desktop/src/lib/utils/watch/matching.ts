import type { ProviderKind, StreamableAnime } from '$lib/types/stream'
import type { EpisodeMatchResult } from './episodes'
import { inferExplicitSeasonIndex, normalizeTitle } from './search'

export type CandidateMappingValidation = {
    accepted: boolean
    adjustment: number
    reason: string
}

export type WatchMatchContext = {
    title?: string | null
    titleJapanese?: string | null
    episodeCount?: number | null
    seasonYear?: number | null
    season?: string | null
    status?: string | null
    format?: string | null
}

export function rankProviderMatches(
    results: StreamableAnime[],
    hint: string,
    desiredEpisode: number | undefined,
    targetProvider: ProviderKind,
    context: WatchMatchContext,
): Array<{ anime: StreamableAnime; score: number }> {
    if (results.length === 0) return []
    return results
        .map(result => ({
            anime: result,
            score: scoreProviderAnimeMatch(result, hint, desiredEpisode, targetProvider, context),
        }))
        .sort((a, b) => b.score - a.score)
}

function scoreProviderAnimeMatch(
    result: StreamableAnime,
    hint: string,
    desiredEpisode: number | undefined,
    targetProvider: ProviderKind,
    context: WatchMatchContext,
): number {
    const normalizedHint = normalizeTitle(hint)
    const desiredSeasonIndex = inferExplicitSeasonIndex(
        hint,
        context.title ?? '',
        context.titleJapanese ?? '',
    )
    const desiredEpisodeCount = Number(context.episodeCount)
    const desiredYear = Number(context.seasonYear)
    const desiredSeasonName = normalizeSeasonName(context.season ?? null)
    const desiredStatus = normalizeStatus(context.status ?? null)
    const desiredFormat = normalizeMediaType(context.format ?? null)

    const candidate = normalizeTitle(result.title)
    const candidateSeasonIndex = inferExplicitSeasonIndex(result.title)
    const candidateSeasonName = normalizeSeasonName(result.season ?? null)
    const candidateStatus = normalizeStatus(result.status ?? null)
    let score = 0

    if (candidate === normalizedHint) score += 500
    if (candidate.includes(normalizedHint) || normalizedHint.includes(candidate)) score += 250

    const hintTokens = normalizedHint.split(' ').filter(Boolean)
    const candidateTokens = new Set(candidate.split(' ').filter(Boolean))
    let overlap = 0
    for (const token of hintTokens) {
        if (candidateTokens.has(token)) overlap += 1
    }
    score += overlap * 10
    score -= Math.abs(candidate.length - normalizedHint.length) * 0.1

    if (Number.isFinite(desiredEpisode)) {
        const available = Number(result.available_episodes)
        if (Number.isFinite(available) && available >= (desiredEpisode ?? 1)) score += 20
        if (Number.isFinite(available) && available < (desiredEpisode ?? 1)) score -= 30
        if (!Number.isFinite(available) || available <= 0) score -= 5

        if (Number.isFinite(desiredEpisodeCount) && desiredEpisodeCount > 0 && Number.isFinite(available)) {
            const diff = Math.abs(available - desiredEpisodeCount)
            if (diff === 0) score += 75
            else if (diff <= 2) score += 45
            else if (diff <= 6) score += 20
            else if (available > desiredEpisodeCount + Math.max(10, Math.floor(desiredEpisodeCount / 2))) {
                score -= 40
            }
        }
    }

    if (Number.isFinite(desiredSeasonIndex) && (desiredSeasonIndex ?? 1) > 1) {
        const seasonWeight = targetProvider === 'animepahe' ? 1.2 : 1
        if (candidateSeasonIndex === desiredSeasonIndex) {
            score += Math.trunc(170 * seasonWeight)
        } else if (candidateSeasonIndex === null) {
            score -= Math.trunc(35 * seasonWeight)
        } else {
            score -= Math.trunc(
                Math.abs(candidateSeasonIndex - (desiredSeasonIndex ?? candidateSeasonIndex)) *
                    110 *
                    seasonWeight,
            )
        }
    }

    const candidateYear = Number(result.year)
    if (Number.isFinite(desiredYear) && desiredYear > 0 && Number.isFinite(candidateYear) && candidateYear > 0) {
        const diff = Math.abs(candidateYear - desiredYear)
        if (diff === 0) score += 130
        else if (diff === 1) score += 40
        else score -= 80
    }

    if (desiredSeasonName && candidateSeasonName) {
        score += desiredSeasonName === candidateSeasonName ? 28 : -16
    }

    if (desiredStatus && candidateStatus) {
        score += desiredStatus === candidateStatus ? 20 : -10
    }

    const candidateFormat = normalizeMediaType(result.media_type ?? null)
    if (desiredFormat && candidateFormat) {
        score += desiredFormat === candidateFormat ? 32 : -25
    }

    return score
}

function normalizeMediaType(value: string | null | undefined): string {
    const normalized = (value ?? '').toLowerCase().trim()
    if (!normalized) return ''
    if (normalized.includes('movie')) return 'movie'
    if (normalized.includes('ona')) return 'ona'
    if (normalized.includes('ova')) return 'ova'
    if (normalized.includes('special')) return 'special'
    if (normalized.includes('tv')) return 'tv'
    return normalized
}

function normalizeStatus(value: string | null | undefined): string {
    const normalized = (value ?? '').toLowerCase().trim()
    if (!normalized) return ''
    if (normalized.includes('release') || normalized.includes('air')) return 'releasing'
    if (normalized.includes('finish') || normalized.includes('complete')) return 'finished'
    if (normalized.includes('upcoming') || normalized.includes('not yet')) return 'upcoming'
    return normalized
}

function normalizeSeasonName(value: string | null | undefined): string {
    const normalized = (value ?? '').toLowerCase().trim()
    if (!normalized) return ''
    if (normalized.includes('winter')) return 'winter'
    if (normalized.includes('spring')) return 'spring'
    if (normalized.includes('summer')) return 'summer'
    if (normalized.includes('fall') || normalized.includes('autumn')) return 'fall'
    return normalized
}

export function validateCandidateMapping(
    targetProvider: ProviderKind,
    candidate: StreamableAnime,
    match: EpisodeMatchResult,
    expectedEpisodeCount: number,
    desiredSeasonIndex: number,
    desiredYear: number,
): CandidateMappingValidation {
    if (!match.episode) {
        return {
            accepted: false,
            adjustment: -300,
            reason: 'no_episode_match',
        }
    }

    if (!Number.isFinite(desiredSeasonIndex) || desiredSeasonIndex <= 1) {
        if (match.kind === 'none') {
            return {
                accepted: false,
                adjustment: -260,
                reason: 'no_mapping',
            }
        }
        return {
            accepted: true,
            adjustment: match.kind === 'ordinal' ? -30 : 0,
            reason: 'ok',
        }
    }

    const candidateSeasonIndex = inferExplicitSeasonIndex(candidate.title)
    const hasExplicitSeason = Number.isFinite(candidateSeasonIndex)
    const seasonAligned = hasExplicitSeason && candidateSeasonIndex === desiredSeasonIndex
    const seasonMismatch = hasExplicitSeason && candidateSeasonIndex !== desiredSeasonIndex
    const candidateYear = Number(candidate.year)
    const yearAligned =
        Number.isFinite(candidateYear) &&
        candidateYear > 0 &&
        Number.isFinite(desiredYear) &&
        desiredYear > 0 &&
        Math.abs(candidateYear - desiredYear) <= 1
    const hasExpectedCount = Number.isFinite(expectedEpisodeCount) && expectedEpisodeCount > 0
    const standaloneUpperBound = hasExpectedCount ? expectedEpisodeCount + 2 : 15
    const cumulativeThreshold = hasExpectedCount
        ? expectedEpisodeCount + Math.max(10, Math.floor(expectedEpisodeCount / 2))
        : 30
    const hasShiftedRange = Number.isFinite(match.minNumber) && match.minNumber > 1
    const appearsStandalone =
        Number.isFinite(match.minNumber) &&
        match.minNumber === 1 &&
        Number.isFinite(match.range) &&
        match.range <= standaloneUpperBound
    const appearsCumulative =
        Number.isFinite(match.minNumber) &&
        match.minNumber === 1 &&
        Number.isFinite(match.range) &&
        match.range > cumulativeThreshold

    if (seasonMismatch) {
        return {
            accepted: false,
            adjustment: -250,
            reason: 'explicit_season_mismatch',
        }
    }

    if (match.kind === 'ordinal') {
        return {
            accepted: false,
            adjustment: -250,
            reason: 'ordinal_disabled_for_later_season',
        }
    }

    if (match.kind === 'tvdb_offset' && !hasShiftedRange && !appearsCumulative) {
        return {
            accepted: false,
            adjustment: -220,
            reason: 'tvdb_offset_ambiguous_range',
        }
    }

    if (match.kind === 'season_window' && !seasonAligned && !(yearAligned && appearsCumulative)) {
        return {
            accepted: false,
            adjustment: -210,
            reason: 'season_window_without_support',
        }
    }

    if (
        targetProvider === 'animepahe' &&
        match.kind === 'exact' &&
        appearsStandalone &&
        !seasonAligned &&
        !yearAligned
    ) {
        return {
            accepted: false,
            adjustment: -180,
            reason: 'animepahe_exact_without_season_evidence',
        }
    }

    let adjustment = 0
    if (seasonAligned) adjustment += 80
    if (yearAligned) adjustment += 35
    if (match.kind === 'season_window' && seasonAligned) adjustment += 20
    if (match.kind === 'exact' && seasonAligned) adjustment += 24
    if (targetProvider === 'animepahe' && appearsStandalone && !seasonAligned && !yearAligned) {
        adjustment -= 55
    }

    return {
        accepted: true,
        adjustment,
        reason: 'ok',
    }
}

export function scoreEpisodeMappingConfidence(
    match: EpisodeMatchResult,
    expectedEpisodeCount: number,
    desiredSeasonIndex: number,
): number {
    let score = 0

    if (match.kind === 'tvdb_offset') score += 240
    else if (match.kind === 'shifted_offset') score += 220
    else if (match.kind === 'exact') score += 180
    else if (match.kind === 'season_window') score += 120
    else if (match.kind === 'ordinal') score -= 60
    else score -= 260

    if (Number.isFinite(desiredSeasonIndex) && desiredSeasonIndex > 1) {
        if (match.kind === 'ordinal') score -= 220
        if (match.kind === 'season_window') score -= 45
        if (
            match.kind === 'exact' &&
            Number.isFinite(expectedEpisodeCount) &&
            expectedEpisodeCount > 0 &&
            match.minNumber === 1 &&
            Number.isFinite(match.range) &&
            match.range > expectedEpisodeCount + Math.max(10, Math.floor(expectedEpisodeCount / 2))
        ) {
            score -= 95
        }
        if (
            match.kind === 'tvdb_offset' &&
            Number.isFinite(expectedEpisodeCount) &&
            expectedEpisodeCount > 0 &&
            match.minNumber === 1 &&
            Number.isFinite(match.range) &&
            match.range <= expectedEpisodeCount + 2
        ) {
            score -= 140
        }
    }

    return score
}