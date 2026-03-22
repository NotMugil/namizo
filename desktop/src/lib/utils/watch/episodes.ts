import type { AnimeDetails } from '$lib/types/anime'
import type { StreamingEpisode } from '$lib/types/stream'

export type EpisodeMatchKind =
    | 'none'
    | 'tvdb_offset'
    | 'shifted_offset'
    | 'season_window'
    | 'exact'
    | 'ordinal'

export type EpisodeMatchResult = {
    episode: StreamingEpisode | null
    kind: EpisodeMatchKind
    minNumber: number
    maxNumber: number
    range: number
}

export function parseRequestedEpisode(value: string | null): number {
    const parsed = Number(value)
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 1
}

export function parseEpisodeNumber(value: string | number | null | undefined): number {
    if (typeof value === 'number') {
        return Number.isFinite(value) ? value : Number.NaN
    }

    if (typeof value !== 'string') return Number.NaN

    const parsed = Number(value)
    if (Number.isFinite(parsed)) return parsed

    const match = value.match(/\d+(\.\d+)?/)
    if (!match) return Number.NaN

    const fallback = Number(match[0])
    return Number.isFinite(fallback) ? fallback : Number.NaN
}

export function buildAniListEpisodeNumbers(
    count: number | null | undefined,
    providerEpisodes: StreamingEpisode[],
): number[] {
    const parsedCount = Number(count)
    if (Number.isFinite(parsedCount) && parsedCount > 0) {
        const total = Math.trunc(parsedCount)
        return Array.from({ length: total }, (_, index) => index + 1)
    }

    const fromProvider = providerEpisodes
        .map(episode => parseEpisodeNumber(episode.number))
        .filter(number => Number.isFinite(number) && number > 0)

    return Array.from(new Set(fromProvider)).sort((a, b) => a - b)
}

export function resolveEpisodeByNumber(
    providerEpisodes: StreamingEpisode[],
    number: number,
    options?: {
        requireSourceId?: boolean
        expectedEpisodeCount?: number | null
        seasonIndex?: number | null
        tvdbOffset?: number | null
    },
): EpisodeMatchResult {
    const requireSourceId = options?.requireSourceId === true
    const expectedEpisodeCount = Number(options?.expectedEpisodeCount)
    const seasonIndex = Number(options?.seasonIndex)
    const tvdbOffset = Number(options?.tvdbOffset)

    const eligibleEpisodes = requireSourceId
        ? providerEpisodes.filter(episode => Boolean(episode.source_id))
        : providerEpisodes

    if (eligibleEpisodes.length === 0 || !Number.isFinite(number) || number <= 0) {
        return {
            episode: null,
            kind: 'none',
            minNumber: Number.NaN,
            maxNumber: Number.NaN,
            range: Number.NaN,
        }
    }

    const ordered = [...eligibleEpisodes].sort((a, b) => {
        const aNum = parseEpisodeNumber(a.number)
        const bNum = parseEpisodeNumber(b.number)
        if (!Number.isFinite(aNum) && !Number.isFinite(bNum)) return 0
        if (!Number.isFinite(aNum)) return 1
        if (!Number.isFinite(bNum)) return -1
        return aNum - bNum
    })

    const pickByEpisodeNumber = (targetNumber: number): StreamingEpisode | null => {
        if (!Number.isFinite(targetNumber) || targetNumber <= 0) return null
        return (
            ordered.find(episode => parseEpisodeNumber(episode.number) === targetNumber) ??
            ordered.find(episode => episode.number.trim() === String(targetNumber)) ??
            null
        )
    }

    const parsedNumbers = ordered
        .map(episode => parseEpisodeNumber(episode.number))
        .filter(value => Number.isFinite(value) && value > 0)
    const minNumber = parsedNumbers.length ? Math.min(...parsedNumbers) : Number.NaN
    const maxNumber = parsedNumbers.length ? Math.max(...parsedNumbers) : Number.NaN
    const range = Number.isFinite(minNumber) && Number.isFinite(maxNumber)
        ? maxNumber - minNumber + 1
        : Number.NaN
    const hasExpectedCount = Number.isFinite(expectedEpisodeCount) && expectedEpisodeCount > 0
    const cumulativeThreshold = hasExpectedCount
        ? expectedEpisodeCount + Math.max(12, Math.floor(expectedEpisodeCount / 2))
        : Number.NaN
    const appearsCumulative =
        Number.isFinite(minNumber) &&
        Number.isFinite(range) &&
        minNumber === 1 &&
        Number.isFinite(cumulativeThreshold) &&
        range > cumulativeThreshold

    if (Number.isFinite(tvdbOffset) && tvdbOffset > 0) {
        const tvdbMapped = pickByEpisodeNumber(tvdbOffset + number)
        const ambiguousStandaloneRange =
            Number.isFinite(minNumber) &&
            minNumber === 1 &&
            (!hasExpectedCount || (Number.isFinite(range) && range <= expectedEpisodeCount + 2))
        if (tvdbMapped && (!ambiguousStandaloneRange || appearsCumulative || minNumber > 1)) {
            return {
                episode: tvdbMapped,
                kind: 'tvdb_offset',
                minNumber,
                maxNumber,
                range,
            }
        }
    }

    if (
        Number.isFinite(seasonIndex) &&
        seasonIndex > 1 &&
        Number.isFinite(expectedEpisodeCount) &&
        expectedEpisodeCount > 0
    ) {
        // Provider episode numbers can be shifted for later seasons (e.g. 29..37).
        if (Number.isFinite(minNumber) && minNumber > 1) {
            const shifted = pickByEpisodeNumber(minNumber + number - 1)
            if (shifted) {
                return {
                    episode: shifted,
                    kind: 'shifted_offset',
                    minNumber,
                    maxNumber,
                    range,
                }
            }
        }

        // For large cumulative catalogs that still start at 1, prefer the trailing season window.
        if (
            Number.isFinite(maxNumber) &&
            Number.isFinite(range) &&
            minNumber === 1 &&
            appearsCumulative
        ) {
            const seasonTailStart = maxNumber - expectedEpisodeCount + 1
            const seasonMapped = pickByEpisodeNumber(seasonTailStart + number - 1)
            if (seasonMapped) {
                return {
                    episode: seasonMapped,
                    kind: 'season_window',
                    minNumber,
                    maxNumber,
                    range,
                }
            }
        }
    }

    const exact = pickByEpisodeNumber(number)
    if (exact) {
        return {
            episode: exact,
            kind: 'exact',
            minNumber,
            maxNumber,
            range,
        }
    }

    const fallback = ordered[number - 1] ?? null
    if (!fallback) {
        return {
            episode: null,
            kind: 'none',
            minNumber,
            maxNumber,
            range,
        }
    }

    return {
        episode: fallback,
        kind: 'ordinal',
        minNumber,
        maxNumber,
        range,
    }
}

export function syntheticEpisode(number: number, animeId: string): StreamingEpisode {
    return {
        anime_id: animeId,
        number: String(number),
        source_id: null,
    }
}

export function buildAniListTitleMap(anime: AnimeDetails): Record<number, string> {
    const map: Record<number, string> = {}
    for (const episode of anime.episodes) {
        const title = episode.title?.trim()
        if (!title || episode.number <= 0) continue
        map[episode.number] = title
    }
    return map
}

export function episodeTitleForNumber(episodeTitleByNumber: Record<number, string>, number: number): string {
    return episodeTitleByNumber[number] ?? `Episode ${number}`
}

export function findAdjacentEpisode(
    episodeNumbers: number[],
    selectedNumber: number,
    direction: 'prev' | 'next',
): number | null {
    const index = episodeNumbers.indexOf(selectedNumber)
    if (index < 0) return null
    const adjacent = direction === 'prev' ? episodeNumbers[index - 1] : episodeNumbers[index + 1]
    return Number.isFinite(adjacent) ? adjacent : null
}