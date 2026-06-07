import { auth } from '$lib/server/auth';
import { svelteKitHandler } from 'better-auth/svelte-kit';
import { building } from '$app/environment';
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
	try {
		const session = await auth.api.getSession({ headers: event.request.headers });
		if (session) {
			event.locals.session = session.session;
			event.locals.user = session.user;
		}
	} catch (e) {
		console.warn('[auth] getSession failed:', (e as Error)?.message ?? e);
	}

	return svelteKitHandler({ event, resolve, auth, building });
};
