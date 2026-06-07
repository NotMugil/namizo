const ANILIST_API = 'https://graphql.anilist.co';

const MEDIALIST_QUERY = `
query ($userId: Int) {
  MediaListCollection(userId: $userId, type: ANIME) {
    lists {
      entries {
        mediaId
        status
        progress
        score(format: POINT_10)
        notes
        repeat
        startedAt { year month day }
        completedAt { year month day }
        updatedAt
        media {
          title { romaji english }
          coverImage { large }
          bannerImage
          format
          episodes
          genres
          season
          seasonYear
          popularity
          averageScore
          status
        }
      }
    }
  }
}`;

type AniListStatus = 'CURRENT' | 'COMPLETED' | 'PAUSED' | 'DROPPED' | 'PLANNING' | 'REPEATING';

const STATUS_MAP: Record<AniListStatus, string> = {
	CURRENT:   'WATCHING',
	COMPLETED: 'COMPLETED',
	PAUSED:    'PAUSED',
	DROPPED:   'DROPPED',
	PLANNING:  'PLANNING',
	REPEATING: 'REWATCHING'
};

function fmtDate(d: { year?: number; month?: number; day?: number } | null): string | null {
	if (!d?.year) return null;
	const m = String(d.month ?? 1).padStart(2, '0');
	const day = String(d.day ?? 1).padStart(2, '0');
	return `${d.year}-${m}-${day}`;
}

export interface AniListSyncEntry {
	anilist_id: number;
	title: string;
	cover_image: string | null;
	banner_image: string | null;
	format: string | null;
	episode_total: number | null;
	score: number | null;
	genres: string[];
	anilist_status: string | null;
	season: string | null;
	season_year: number | null;
	popularity: number | null;
	average_score: number | null;
	// User's personal watch dates (not anime release dates)
	start_date: string | null;
	end_date: string | null;
	notes: string | null;
	status: string;
	progress: number;
	progress_percent: number;
	rewatches: number;
	last_episode: number | null;
	last_watched_at: number | null;
	updated_at: number;
	created_at: number;
}

export async function fetchAniListEntries(
	anilistUserId: number,
	accessToken: string
): Promise<AniListSyncEntry[]> {
	const res = await fetch(ANILIST_API, {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			Authorization: `Bearer ${accessToken}`
		},
		body: JSON.stringify({ query: MEDIALIST_QUERY, variables: { userId: anilistUserId } })
	});

	if (!res.ok) throw new Error(`AniList API error: ${res.status}`);

	const json: {
		data: {
			MediaListCollection: {
				lists: {
					entries: {
						mediaId: number;
						status: AniListStatus;
						progress: number;
						score: number;
						notes: string | null;
						repeat: number;
						startedAt: { year?: number; month?: number; day?: number } | null;
						completedAt: { year?: number; month?: number; day?: number } | null;
						updatedAt: number;
						media: {
							title: { romaji: string; english: string | null };
							coverImage: { large: string } | null;
							bannerImage: string | null;
							format: string | null;
							episodes: number | null;
							genres: string[];
							season: string | null;
							seasonYear: number | null;
							popularity: number | null;
							averageScore: number | null;
							status: string | null;
						};
					}[];
				}[];
			};
		};
	} = await res.json();

	const entries: AniListSyncEntry[] = [];
	for (const list of json.data.MediaListCollection.lists) {
		for (const e of list.entries) {
			const episodeTotal = e.media.episodes ?? null;
			const progress = e.progress ?? 0;
			entries.push({
				anilist_id: e.mediaId,
				title: e.media.title.english ?? e.media.title.romaji,
				cover_image: e.media.coverImage?.large ?? null,
				banner_image: e.media.bannerImage ?? null,
				format: e.media.format ?? null,
				episode_total: episodeTotal,
				// AniList returns 0 for unrated — store as null
				score: e.score > 0 ? e.score : null,
				genres: e.media.genres ?? [],
				anilist_status: e.media.status ?? null,
				season: e.media.season ?? null,
				season_year: e.media.seasonYear ?? null,
				popularity: e.media.popularity ?? null,
				average_score: e.media.averageScore ?? null,
				// User's personal watch start/end dates (not the anime's release dates)
				start_date: fmtDate(e.startedAt),
				end_date: fmtDate(e.completedAt),
				notes: e.notes ?? null,
				status: STATUS_MAP[e.status] ?? 'PLANNING',
				progress,
				progress_percent: episodeTotal ? Math.round((progress / episodeTotal) * 100) : 0,
				// Use the actual AniList repeat count, not a boolean derived from status
				rewatches: e.repeat ?? 0,
				last_episode: progress > 0 ? progress : null,
				last_watched_at: e.updatedAt ?? null,
				updated_at: e.updatedAt ?? Math.floor(Date.now() / 1000),
				created_at: Math.floor(Date.now() / 1000)
			});
		}
	}
	return entries;
}
