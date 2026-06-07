import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { db } from '$lib/server/db';
import { libraryEntry } from '$lib/server/db/schema';
import { auth } from '$lib/server/auth';
import type { LibraryEntry } from '$lib/types/library';

export const POST: RequestHandler = async ({ request }) => {
	const session = await auth.api.getSession({ headers: request.headers });
	if (!session?.user) throw error(401, 'Not authenticated');

	const { entries }: { entries: LibraryEntry[] } = await request.json();
	if (!Array.isArray(entries) || entries.length === 0) {
		return json({ pushed: 0 });
	}

	const rows = entries.map((e) => ({
		id: crypto.randomUUID(),
		userId: session.user.id,
		anilistId: e.anilist_id,
		title: e.title,
		coverImage: e.cover_image ?? null,
		format: e.format ?? null,
		episodeTotal: e.episode_total ?? null,
		score: e.score ?? null,
		genres: e.genres ?? [],
		season: e.season ?? null,
		seasonYear: e.season_year ?? null,
		userStartDate: e.start_date ?? null,
		userEndDate: e.end_date ?? null,
		rewatches: e.rewatches ?? 0,
		notes: e.notes ?? null,
		status: e.status,
		progress: e.progress ?? 0,
		lastEpisode: e.last_episode ?? null,
		lastWatchedAt: e.last_watched_at ?? null,
		localUpdatedAt: e.updated_at ?? null
	}));

	await db
		.insert(libraryEntry)
		.values(rows)
		.onConflictDoUpdate({
			target: [libraryEntry.userId, libraryEntry.anilistId],
			set: {
				title: libraryEntry.title,
				coverImage: libraryEntry.coverImage,
				format: libraryEntry.format,
				episodeTotal: libraryEntry.episodeTotal,
				score: libraryEntry.score,
				genres: libraryEntry.genres,
				season: libraryEntry.season,
				seasonYear: libraryEntry.seasonYear,
				userStartDate: libraryEntry.userStartDate,
				userEndDate: libraryEntry.userEndDate,
				rewatches: libraryEntry.rewatches,
				notes: libraryEntry.notes,
				status: libraryEntry.status,
				progress: libraryEntry.progress,
				lastEpisode: libraryEntry.lastEpisode,
				lastWatchedAt: libraryEntry.lastWatchedAt,
				localUpdatedAt: libraryEntry.localUpdatedAt,
				syncedAt: new Date()
			}
		});

	return json({ pushed: rows.length });
};
