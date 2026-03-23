import type {
    LibraryEntry,
    LibraryFacets,
    KnownLibraryReleaseStatus,
    LibraryReleaseFilter,
    LibrarySortValue,
} from "$lib/types/library";
import type { AnimeSummary } from "$lib/types/anime";
import { LIBRARY_DEFAULT_SEASONS } from "$lib/constants/library";

const KNOWN_RELEASE_STATUSES: KnownLibraryReleaseStatus[] = [
    "FINISHED",
    "RELEASING",
    "NOT_YET_RELEASED",
];

export interface DerivedLibraryOptions {
    genres: string[];
    formats: string[];
    seasons: string[];
    years: number[];
    releaseStatuses: KnownLibraryReleaseStatus[];
}

export function sortedUnique(values: string[]): string[] {
    return [...new Set(values)].sort((left, right) => left.localeCompare(right));
}

export function normalizeGenre(value: string): string {
    return value.trim().replace(/\s+/g, " ").toLowerCase();
}

export function formatSeasonLabel(value: string): string {
    const normalized = value.toLowerCase();
    return normalized.charAt(0).toUpperCase() + normalized.slice(1);
}

export function releaseLabel(value: KnownLibraryReleaseStatus): string {
    if (value === "NOT_YET_RELEASED") return "Upcoming";
    if (value === "RELEASING") return "Releasing";
    return "Finished";
}

export function selectedLibraryGenreLabel(selectedGenres: string[]): string {
    return selectedGenres.length === 0 ? "Genres" : `${selectedGenres.length} selected`;
}

export function buildLibraryReleaseOptions(
    availableReleaseStatuses: KnownLibraryReleaseStatus[],
): Array<{ value: LibraryReleaseFilter; label: string }> {
    return [
        { value: "ALL", label: "All Release Statuses" },
        ...availableReleaseStatuses.map((value) => ({
            value,
            label: releaseLabel(value),
        })),
    ];
}

export function buildLibrarySeasonOptions(
    availableSeasons: string[],
): Array<{ value: string; label: string }> {
    const source = availableSeasons.length > 0 ? availableSeasons : LIBRARY_DEFAULT_SEASONS;
    return [
        { value: "ALL", label: "All Seasons" },
        ...source.map((value) => ({
            value: value.toUpperCase(),
            label: formatSeasonLabel(value),
        })),
    ];
}

export function compareNullableNumber(
    left: number | null | undefined,
    right: number | null | undefined,
    direction: "asc" | "desc",
): number {
    const leftValue = left ?? null;
    const rightValue = right ?? null;
    const leftMissing = leftValue === null;
    const rightMissing = rightValue === null;

    if (leftMissing && rightMissing) return 0;
    if (leftMissing) return 1;
    if (rightMissing) return -1;

    return direction === "asc" ? leftValue - rightValue : rightValue - leftValue;
}

export function compareLibraryEntries(
    left: LibraryEntry,
    right: LibraryEntry,
    sortValue: LibrarySortValue,
): number {
    const bySort = (() => {
        switch (sortValue) {
            case "A_Z":
                return left.title.localeCompare(right.title);
            case "Z_A":
                return right.title.localeCompare(left.title);
            case "POPULARITY_DESC":
                return compareNullableNumber(left.popularity, right.popularity, "desc");
            case "POPULARITY_ASC":
                return compareNullableNumber(left.popularity, right.popularity, "asc");
            case "USER_SCORE_DESC":
                return compareNullableNumber(left.score, right.score, "desc");
            case "USER_SCORE_ASC":
                return compareNullableNumber(left.score, right.score, "asc");
            case "RATING_DESC":
                return compareNullableNumber(left.average_score, right.average_score, "desc");
            case "RATING_ASC":
                return compareNullableNumber(left.average_score, right.average_score, "asc");
            case "PROGRESS_DESC":
                return compareNullableNumber(left.progress, right.progress, "desc");
            case "PROGRESS_ASC":
                return compareNullableNumber(left.progress, right.progress, "asc");
            case "OLDEST":
                return compareNullableNumber(left.season_year, right.season_year, "asc");
            case "NEWEST":
                return compareNullableNumber(left.season_year, right.season_year, "desc");
            default:
                return 0;
        }
    })();

    if (bySort !== 0) return bySort;
    return left.title.localeCompare(right.title);
}

export function horizontalPadding(width: number): number {
    if (width >= 1024) return 96;
    if (width >= 768) return 80;
    return 64;
}

export function computeCardsPerRow(
    contentWidth: number,
    viewportWidth: number,
    cardWidth: number,
    cardGap: number,
): number {
    const usableWidth = Math.max(0, contentWidth - horizontalPadding(viewportWidth));
    return Math.max(1, Math.floor((usableWidth + cardGap) / (cardWidth + cardGap)));
}

export function chunkRows<T>(items: T[], size: number): T[][] {
    const rows: T[][] = [];
    for (let index = 0; index < items.length; index += size) {
        rows.push(items.slice(index, index + size));
    }
    return rows;
}

export function withPlaceholders<T>(row: T[], size: number): Array<T | null> {
    if (row.length >= size) return [...row];
    return [...row, ...Array.from({ length: size - row.length }, () => null)];
}

export function deriveOptionsFromEntries(entries: LibraryEntry[]): DerivedLibraryOptions {
    const genres = sortedUnique(
        entries
            .flatMap((entry) => entry.genres ?? [])
            .map((value) => value.trim())
            .filter((value) => value.length > 0),
    );
    const formats = sortedUnique(
        entries
            .map((entry) => entry.format ?? "")
            .map((value) => value.trim())
            .filter((value) => value.length > 0),
    );
    const seasons = sortedUnique(
        entries
            .map((entry) => entry.season ?? "")
            .map((value) => value.trim().toUpperCase())
            .filter((value) => value.length > 0),
    );
    const years = [...new Set(entries.map((entry) => entry.season_year).filter(isDefined))].sort(
        (left, right) => right - left,
    );
    const releaseStatuses = normalizeReleaseStatuses(
        entries
            .map((entry) => (entry.anilist_status ?? "").trim().toUpperCase())
            .filter((value) => value.length > 0),
    );

    return { genres, formats, seasons, years, releaseStatuses };
}

export function deriveOptionsFromFacets(facets: LibraryFacets | null): DerivedLibraryOptions {
    if (!facets) {
        return { genres: [], formats: [], seasons: [], years: [], releaseStatuses: [] };
    }

    const genres = sortedUnique(
        (facets.genres ?? []).map((value) => value.trim()).filter((value) => value.length > 0),
    );
    const seasons = sortedUnique(
        (facets.seasons ?? [])
            .map((value) => value.trim().toUpperCase())
            .filter((value) => value.length > 0),
    );
    const years = [...(facets.years ?? [])]
        .map((value) => Number(value))
        .filter((value) => Number.isFinite(value))
        .sort((left, right) => right - left);
    const releaseStatuses = normalizeReleaseStatuses(
        (facets.release_statuses ?? [])
            .map((value) => value.trim().toUpperCase())
            .filter((value) => value.length > 0),
    );

    return { genres, formats: [], seasons, years, releaseStatuses };
}

export function normalizeReleaseStatuses(values: string[]): KnownLibraryReleaseStatus[] {
    const valueSet = new Set(values.map((value) => value.trim().toUpperCase()));
    return KNOWN_RELEASE_STATUSES.filter((value) => valueSet.has(value));
}

export function toSummaryFromLibraryEntry(entry: LibraryEntry): AnimeSummary {
    const fallbackImage = entry.cover_image || entry.banner_image || "/favicon.png";
    return {
        id: entry.anilist_id,
        title: entry.title,
        cover_image: fallbackImage,
        description: entry.notes ?? null,
        average_score: entry.average_score,
        genres: entry.genres ?? [],
        format: entry.format?.trim() ? entry.format : null,
        episodes: entry.episode_total ?? null,
        banner_image: entry.banner_image ?? null,
        trailer_id: null,
        status: entry.anilist_status ?? null,
        next_airing_episode: null,
        next_airing_at: null,
    };
}

function isDefined(value: number | null): value is number {
    return value != null;
}
