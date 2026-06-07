import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { auth } from '$lib/server/auth';
import { db } from '$lib/server/db';
import { verification } from '$lib/server/db/schema';
import { env } from '$env/dynamic/private';

export const GET: RequestHandler = async ({ request }) => {
	if (!env.ANILIST_CLIENT_ID) throw error(503, 'AniList integration is not configured');

	const session = await auth.api.getSession({ headers: request.headers });
	if (!session?.user) throw error(401, 'Not authenticated');

	const state = crypto.randomUUID();
	const now = new Date();

	await db.insert(verification).values({
		id: crypto.randomUUID(),
		identifier: `anilist_oauth:${state}`,
		value: session.user.id,
		expiresAt: new Date(now.getTime() + 10 * 60 * 1000), // 10 min TTL
		createdAt: now,
		updatedAt: now
	});

	const redirectUri = env.ANILIST_REDIRECT_URI ?? '';
	const url = `https://anilist.co/api/v2/oauth/authorize?client_id=${env.ANILIST_CLIENT_ID}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=code&state=${state}`;

	return json({ url });
};
