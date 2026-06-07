import type { PageServerLoad } from './$types';
import { db } from '$lib/server/db';
import { anilistConnection } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

const ANILIST_API = 'https://graphql.anilist.co';
const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const SCHEDULE_QUERY = `
query ($from: Int, $to: Int, $page: Int) {
  Page(page: $page, perPage: 50) {
    pageInfo { hasNextPage }
    airingSchedules(airingAt_greater: $from, airingAt_lesser: $to, sort: TIME) {
      id
      airingAt
      episode
      media {
        id
        title { romaji english }
        coverImage { large }
        format
        episodes
        averageScore
        studios(isMain: true) { nodes { name } }
      }
    }
  }
}`;

export interface ScheduleEntry {
	id: number;
	airingAt: number;
	episode: number;
	media: {
		id: number;
		title: string;
		coverImage: string | null;
		format: string | null;
		episodes: number | null;
		averageScore: number | null;
		studio: string | null;
	};
}

export interface DayGroup {
	date: string;      // "2025-06-04"
	dayName: string;   // "Thursday"
	shortDay: string;  // "Thu"
	monthDay: string;  // "Jun 4"
	isToday: boolean;
	isPast: boolean;
	entries: ScheduleEntry[];
}

async function fetchSchedulePage(from: number, to: number, page: number): Promise<{
	entries: ScheduleEntry[];
	hasNextPage: boolean;
}> {
	const res = await fetch(ANILIST_API, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ query: SCHEDULE_QUERY, variables: { from, to, page } })
	});

	if (!res.ok) return { entries: [], hasNextPage: false };

	const json: {
		data?: {
			Page?: {
				pageInfo?: { hasNextPage: boolean };
				airingSchedules?: {
					id: number;
					airingAt: number;
					episode: number;
					media: {
						id: number;
						title: { romaji: string; english: string | null };
						coverImage: { large: string } | null;
						format: string | null;
						episodes: number | null;
						averageScore: number | null;
						studios: { nodes: { name: string }[] };
					};
				}[];
			};
		};
	} = await res.json();

	const schedules = json.data?.Page?.airingSchedules ?? [];
	const entries: ScheduleEntry[] = schedules.map((s) => ({
		id: s.id,
		airingAt: s.airingAt,
		episode: s.episode,
		media: {
			id: s.media.id,
			title: s.media.title.english ?? s.media.title.romaji,
			coverImage: s.media.coverImage?.large ?? null,
			format: s.media.format ?? null,
			episodes: s.media.episodes ?? null,
			averageScore: s.media.averageScore ?? null,
			studio: s.media.studios.nodes[0]?.name ?? null
		}
	}));

	return { entries, hasNextPage: json.data?.Page?.pageInfo?.hasNextPage ?? false };
}

export const load: PageServerLoad = async (event) => {
	// 21-day window: 7 days ago → 13 days from now
	const todayStart = new Date();
	todayStart.setUTCHours(0, 0, 0, 0);

	const from = Math.floor(todayStart.getTime() / 1000) - 7 * 86_400;
	const to   = Math.floor(todayStart.getTime() / 1000) + 14 * 86_400;

	// Paginate up to 5 pages to cover 21 days of data
	const allEntries: ScheduleEntry[] = [];
	let scheduleError = false;
	try {
		for (let page = 1; page <= 5; page++) {
			const { entries, hasNextPage } = await fetchSchedulePage(from, to, page);
			allEntries.push(...entries);
			if (!hasNextPage) break;
		}
	} catch {
		scheduleError = true;
	}

	// Build map: UTC date key → entries
	const dayMap = new Map<string, ScheduleEntry[]>();
	for (const entry of allEntries) {
		const d = new Date(entry.airingAt * 1000);
		const key = d.toISOString().split('T')[0];
		if (!dayMap.has(key)) dayMap.set(key, []);
		dayMap.get(key)!.push(entry);
	}

	// Generate all 21 days (including empty ones) so the tab bar is always full
	const today = new Date();
	today.setUTCHours(0, 0, 0, 0);

	const days: DayGroup[] = [];
	for (let offset = -7; offset <= 13; offset++) {
		const d = new Date(today);
		d.setUTCDate(today.getUTCDate() + offset);
		const dateKey = d.toISOString().split('T')[0];
		const entries = (dayMap.get(dateKey) ?? []).sort((a, b) => a.airingAt - b.airingAt);

		days.push({
			date: dateKey,
			dayName: DAY_NAMES[d.getUTCDay()],
			shortDay: DAY_NAMES[d.getUTCDay()].slice(0, 3),
			monthDay: `${MONTH_NAMES[d.getUTCMonth()]} ${d.getUTCDate()}`,
			isToday: offset === 0,
			isPast: offset < 0,
			entries
		});
	}

	// User's currently-watching AniList IDs for highlighting
	let userAnilistIds: number[] = [];
	if (event.locals.user) {
		const connection = await db
			.select({ anilistId: anilistConnection.anilistId, accessToken: anilistConnection.accessToken })
			.from(anilistConnection)
			.where(eq(anilistConnection.userId, event.locals.user.id))
			.then(r => r[0] ?? null);

		if (connection) {
			try {
				const listRes = await fetch(ANILIST_API, {
					method: 'POST',
					headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${connection.accessToken}` },
					body: JSON.stringify({
						query: `query ($id: Int) { MediaListCollection(userId: $id, type: ANIME, status: CURRENT) {
							lists { entries { mediaId } }
						}}`,
						variables: { id: connection.anilistId }
					})
				});
				if (listRes.ok) {
					const listJson: { data: { MediaListCollection: { lists: { entries: { mediaId: number }[] }[] } } } = await listRes.json();
					for (const list of listJson.data.MediaListCollection.lists)
						for (const e of list.entries) userAnilistIds.push(e.mediaId);
				}
			} catch { /* non-fatal */ }
		}
	}

	return { days, userAnilistIds, scheduleError };
};
