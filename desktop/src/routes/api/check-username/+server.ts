import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { db } from '$lib/server/db';
import { user } from '$lib/server/db/schema';

export const GET: RequestHandler = async ({ url, locals }) => {
	const username = url.searchParams.get('u')?.trim().toLowerCase() ?? '';

	if (!username || username.length < 3) return json({ available: false, message: 'Too short' });
	if (!/^[a-z0-9_]+$/.test(username)) return json({ available: false, message: 'Invalid characters' });

	try {
		const existing = await db.query.user.findFirst({
			where: (u, { eq }) => eq(u.username, username),
			columns: { id: true }
		});

		if (existing && existing.id === locals.user?.id) return json({ available: true, message: 'Current username' });
		return json({ available: !existing, message: existing ? 'Username already taken' : 'Available' });
	} catch {
		return json({ available: null, message: 'Could not check' });
	}
};
