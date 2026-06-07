import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { auth } from '$lib/server/auth';
import { APIError } from 'better-auth/api';
import { parseSetCookieHeader, toCookieOptions } from 'better-auth/cookies';
import { loginSchema } from '$lib/validators/auth';
import { db } from '$lib/server/db';
import { invite } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

function applyResponseCookies(cookies: import('@sveltejs/kit').Cookies, response: Response) {
	const setCookies = response.headers.get('set-cookie');
	if (!setCookies) return;
	for (const [name, attributes] of parseSetCookieHeader(setCookies)) {
		try {
			cookies.set(name, attributes.value, { ...toCookieOptions(attributes), path: attributes.path || '/' });
		} catch {}
	}
}

export const load: PageServerLoad = (event) => {
	if (event.locals.user) return redirect(302, '/');
	return {};
};

export const actions: Actions = {
	validateCode: async (event) => {
		const formData = await event.request.formData();
		const code = (formData.get('code')?.toString() ?? '').trim().toUpperCase();

		if (code.length < 6) return fail(400, { codeError: 'Enter your full 6-character code.' });

		const [row] = await db.select().from(invite).where(eq(invite.code, code)).limit(1);
		if (!row)       return fail(400, { codeError: "That code doesn't exist." });
		if (row.usedAt) return fail(400, { codeError: 'This code has already been used.' });
		if (row.expiresAt && row.expiresAt < new Date())
			return fail(400, { codeError: 'This code has expired.' });

		return redirect(302, `/register?code=${encodeURIComponent(code)}`);
	},

	signInEmail: async (event) => {
		const formData = await event.request.formData();
		const raw = {
			email: formData.get('email')?.toString() ?? '',
			password: formData.get('password')?.toString() ?? ''
		};

		const parsed = loginSchema.safeParse(raw);
		if (!parsed.success) return fail(400, { signInError: parsed.error.issues[0].message });

		try {
			const response = await auth.api.signInEmail({ body: parsed.data, asResponse: true });
			applyResponseCookies(event.cookies, response);

			if (!response.ok) {
				const data = await response.json() as Record<string, unknown>;
				return fail(response.status, { signInError: (data.message as string) || 'Invalid credentials' });
			}

			const data = await response.json() as Record<string, unknown> | null;
			if (data?.twoFactorRedirect) return { requires2FA: true };
		} catch (error) {
			if (error instanceof APIError)
				return fail(400, { signInError: error.message || 'Invalid credentials' });
			return fail(500, { signInError: 'Something went wrong. Please try again.' });
		}

		return redirect(302, '/');
	},

	verifyTotpLogin: async (event) => {
		const formData = await event.request.formData();
		const code = formData.get('code')?.toString() ?? '';
		if (!code) return fail(400, { signInError: 'Verification code is required.' });

		try {
			const response = await auth.api.verifyTOTP({
				body: { code },
				headers: event.request.headers,
				asResponse: true
			});
			applyResponseCookies(event.cookies, response);

			if (!response.ok) {
				const data = await response.json() as Record<string, unknown>;
				return fail(response.status, { signInError: (data.message as string) || 'Invalid code — check your authenticator app.' });
			}
		} catch (e) {
			if (e instanceof APIError)
				return fail(400, { signInError: e.message || 'Invalid code — check your authenticator app.' });
			return fail(500, { signInError: 'Something went wrong. Please try again.' });
		}

		return redirect(302, '/');
	}
};
