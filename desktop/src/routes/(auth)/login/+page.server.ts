import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { auth } from '$lib/server/auth';
import { APIError } from 'better-auth/api';
import { loginSchema } from '$lib/validators/auth';
import { db } from '$lib/server/db';
import { invite } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

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
			await auth.api.signInEmail({ body: parsed.data });
		} catch (error) {
			if (error instanceof APIError)
				return fail(400, { signInError: error.message || 'Invalid credentials' });
			return fail(500, { signInError: 'Something went wrong. Please try again.' });
		}

		return redirect(302, '/');
	}
};
