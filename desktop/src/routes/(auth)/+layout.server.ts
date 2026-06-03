import type { LayoutServerLoad } from './$types';

interface AniListMedia {
	id: number;
	title: { romaji: string };
	coverImage: { extraLarge: string };
}

export const load: LayoutServerLoad = async ({ locals, fetch }) => {
	// Redirect already-authenticated users away from auth pages
	if (locals.user) {
		const { redirect } = await import('@sveltejs/kit');
		return redirect(302, '/');
	}

	// Fetch posters for FloatingScene background
	try {
		const res = await fetch('https://graphql.anilist.co', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
			body: JSON.stringify({
				query: `{ Page(perPage: 30) { media(sort: POPULARITY_DESC, type: ANIME, isAdult: false) { id title { romaji } coverImage { extraLarge } } } }`
			}),
			signal: AbortSignal.timeout(4000)
		});
		if (!res.ok) return { posters: [] };
		const json = await res.json();
		const media: AniListMedia[] = json.data?.Page?.media ?? [];
		return { posters: media.map((m) => ({ id: m.id, title: m.title.romaji, image: m.coverImage.extraLarge })) };
	} catch {
		return { posters: [] };
	}
};
