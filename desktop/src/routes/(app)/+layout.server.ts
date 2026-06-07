import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';
import { db } from '$lib/server/db';
import { anilistConnection } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

export const load: LayoutServerLoad = async (event) => {
	if (!event.locals.user) {
		return redirect(302, '/login');
	}

	const connection = await db
		.select({ id: anilistConnection.id, anilistUsername: anilistConnection.anilistUsername })
		.from(anilistConnection)
		.where(eq(anilistConnection.userId, event.locals.user.id))
		.then(r => r[0] ?? null);

	return {
		user: event.locals.user,
		anilistConnected: connection !== null,
		anilistUsername: connection?.anilistUsername ?? null
	};
};
