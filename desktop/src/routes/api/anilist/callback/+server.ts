import { redirect, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { db } from '$lib/server/db';
import { anilistConnection } from '$lib/server/db/schema';
import { env } from '$env/dynamic/private';
import { auth } from '$lib/server/auth';

const ANILIST_TOKEN_URL = 'https://anilist.co/api/v2/oauth/token';
const ANILIST_API_URL   = 'https://graphql.anilist.co';

export const GET: RequestHandler = async ({ url, request }) => {
	const code = url.searchParams.get('code');
	if (!code) throw error(400, 'Missing authorization code');

	const session = await auth.api.getSession({ headers: request.headers });
	if (!session?.user) throw redirect(302, '/login');

	// Exchange authorization code for access token
	const tokenRes = await fetch(ANILIST_TOKEN_URL, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
		body: JSON.stringify({
			grant_type:    'authorization_code',
			client_id:     env.ANILIST_CLIENT_ID,
			client_secret: env.ANILIST_CLIENT_SECRET,
			redirect_uri:  env.ANILIST_REDIRECT_URI,
			code
		})
	});

	if (!tokenRes.ok) {
		console.error('[anilist] token exchange failed', await tokenRes.text());
		throw error(502, 'Failed to exchange AniList authorization code');
	}

	const token: { access_token: string; token_type: string; expires_in: number } =
		await tokenRes.json();

	// Fetch the AniList viewer profile to get their ID + username
	const profileRes = await fetch(ANILIST_API_URL, {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			Authorization: `Bearer ${token.access_token}`
		},
		body: JSON.stringify({ query: '{ Viewer { id name } }' })
	});

	const profileJson: { data: { Viewer: { id: number; name: string } } } =
		await profileRes.json();
	const viewer = profileJson.data.Viewer;

	const expiresAt = new Date(Date.now() + token.expires_in * 1000);

	await db
		.insert(anilistConnection)
		.values({
			id: crypto.randomUUID(),
			userId: session.user.id,
			anilistId: viewer.id,
			anilistUsername: viewer.name,
			accessToken: token.access_token,
			tokenType: token.token_type,
			expiresAt
		})
		.onConflictDoUpdate({
			target: anilistConnection.userId,
			set: {
				anilistId: viewer.id,
				anilistUsername: viewer.name,
				accessToken: token.access_token,
				tokenType: token.token_type,
				expiresAt
			}
		});

	throw redirect(302, '/settings#integrations');
};
