import { redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { auth } from '$lib/server/auth';

function clearAuthCookies(cookies: import('@sveltejs/kit').Cookies) {
	cookies.delete('better-auth.two_factor', { path: '/' });
}

export const load: PageServerLoad = async (event) => {
	await auth.api.signOut({ headers: event.request.headers });
	clearAuthCookies(event.cookies);
	return redirect(302, '/login');
};

export const actions: Actions = {
	default: async (event) => {
		await auth.api.signOut({ headers: event.request.headers });
		clearAuthCookies(event.cookies);
		return redirect(302, '/login');
	}
};
