import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { db } from '$lib/server/db';
import { anilistConnection } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';
import { auth } from '$lib/server/auth';
import { fetchAniListEntries } from '$lib/server/anilist';

export const GET: RequestHandler = async ({ request }) => {
	const session = await auth.api.getSession({ headers: request.headers });
	if (!session?.user) throw error(401, 'Not authenticated');

	const connection = await db
		.select()
		.from(anilistConnection)
		.where(eq(anilistConnection.userId, session.user.id))
		.then(r => r[0] ?? null);

	if (!connection) throw error(400, 'AniList not connected');

	const entries = await fetchAniListEntries(connection.anilistId, connection.accessToken);
	return json({ entries, total: entries.length });
};
