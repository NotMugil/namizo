import type { AnimeDetails, AnimeSummary } from "$lib/types/anime";
import type { LibraryEntry } from "$lib/types/library";
import { libraryFetch } from "$lib/api/library";

let librarySnapshot: LibraryEntry[] | null = null;
let librarySnapshotRequest: Promise<LibraryEntry[]> | null = null;

function nowSeconds(): number {
    return Math.floor(Date.now() / 1000);
}

async function loadLibrarySnapshot(force = false): Promise<LibraryEntry[]> {
    if (force || !librarySnapshot) {
        if (!librarySnapshotRequest) {
            librarySnapshotRequest = libraryFetch()
                .then((entries) => {
                    librarySnapshot = entries;
                    return entries;
                })
                .finally(() => {
                    librarySnapshotRequest = null;
                });
        }
        return librarySnapshotRequest;
    }

    return librarySnapshot;
}

export async function findLibraryEntryById(anilistId: number): Promise<LibraryEntry | null> {
    const entries = await loadLibrarySnapshot();
    return entries.find((entry) => entry.anilist_id === anilistId) ?? null;
}

export async function getLibraryStatus(anilistId: number): Promise<LibraryEntry["status"] | null> {
    const entry = await findLibraryEntryById(anilistId);
    return entry?.status ?? null;
}

export function cacheLibraryEntry(entry: LibraryEntry): void {
    if (!librarySnapshot) {
        return;
    }

    const index = librarySnapshot.findIndex((item) => item.anilist_id === entry.anilist_id);
    if (index >= 0) {
        librarySnapshot[index] = entry;
        return;
    }

    librarySnapshot = [entry, ...librarySnapshot];
}

export function removeCachedLibraryEntry(anilistId: number): void {
    if (!librarySnapshot) {
        return;
    }
    librarySnapshot = librarySnapshot.filter((entry) => entry.anilist_id !== anilistId);
}

export function draftLibraryFromSummary(anime: AnimeSummary): LibraryEntry {
    const now = nowSeconds();
    return {
        anilist_id: anime.id,
        title: anime.title,
        cover_image: anime.cover_image ?? null,
        banner_image: anime.banner_image ?? null,
        format: anime.format ?? null,
        episode_total: anime.episodes ?? null,
        score: null,
        genres: anime.genres ?? [],
        anilist_status: null,
        season: null,
        season_year: null,
        popularity: null,
        average_score: anime.average_score ?? null,
        start_date: null,
        end_date: null,
        rewatches: 0,
        notes: null,
        status: "PLANNING",
        progress: 0,
        progress_percent: 0,
        last_episode: null,
        last_watched_at: null,
        created_at: now,
        updated_at: now,
    };
}

export function draftLibraryFromDetails(details: AnimeDetails): LibraryEntry {
    const now = nowSeconds();
    return {
        anilist_id: details.id,
        title: details.title,
        cover_image: details.cover_image ?? null,
        banner_image: details.banner_image ?? null,
        format: details.format ?? null,
        episode_total: details.episode_count ?? null,
        score: null,
        genres: details.genres ?? [],
        anilist_status: details.status ?? null,
        season: details.season ?? null,
        season_year: details.season_year ?? null,
        popularity: details.popularity ?? null,
        average_score: details.average_score ?? null,
        start_date: null,
        end_date: null,
        rewatches: 0,
        notes: null,
        status: "PLANNING",
        progress: 0,
        progress_percent: 0,
        last_episode: null,
        last_watched_at: null,
        created_at: now,
        updated_at: now,
    };
}

export async function resolveLibraryEntryWithState(
    fallback: LibraryEntry,
): Promise<{ entry: LibraryEntry; exists: boolean }> {
    const existing = await findLibraryEntryById(fallback.anilist_id);
    if (existing) {
        return { entry: existing, exists: true };
    }
    return { entry: fallback, exists: false };
}

export async function resolveLibraryEntry(fallback: LibraryEntry): Promise<LibraryEntry> {
    const resolved = await resolveLibraryEntryWithState(fallback);
    return resolved.entry;
}
