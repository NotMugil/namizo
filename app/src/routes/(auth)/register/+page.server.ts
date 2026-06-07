import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { auth } from '$lib/server/auth';
import { APIError } from 'better-auth/api';
import { registerSchema } from '$lib/validators/auth';
import { db } from '$lib/server/db';
import { invite } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

export const load: PageServerLoad = (event) => {
	if (event.locals.user) return redirect(302, '/');
	const code = event.url.searchParams.get('code') ?? '';
	return { prefillCode: code };
};

export const actions: Actions = {
	signUpEmail: async (event) => {
		const formData = await event.request.formData();
		const raw = {
			inviteCode:      formData.get('inviteCode')?.toString()      ?? '',
			username:        formData.get('username')?.toString()        ?? '',
			displayName:     formData.get('displayName')?.toString()     ?? '',
			email:           formData.get('email')?.toString()           ?? '',
			password:        formData.get('password')?.toString()        ?? '',
			confirmPassword: formData.get('confirmPassword')?.toString() ?? ''
		};

		const parsed = registerSchema.safeParse(raw);
		if (!parsed.success)
			return fail(400, { message: parsed.error.issues[0].message, inviteCode: raw.inviteCode });

		const code = parsed.data.inviteCode.trim().toUpperCase();
		const [row] = await db.select().from(invite).where(eq(invite.code, code)).limit(1);
		if (!row)       return fail(400, { message: 'Invalid invite code.', inviteCode: raw.inviteCode });
		if (row.usedAt) return fail(400, { message: 'This invite code has already been used.', inviteCode: raw.inviteCode });
		if (row.expiresAt && row.expiresAt < new Date())
			return fail(400, { message: 'This invite code has expired.', inviteCode: raw.inviteCode });

		try {
			await auth.api.signUpEmail({
				body: {
					name:        parsed.data.displayName,
					email:       parsed.data.email,
					password:    parsed.data.password,
					username:    parsed.data.username,
					displayName: parsed.data.displayName
				}
			});
		} catch (error) {
			if (error instanceof APIError)
				return fail(400, { message: error.message || 'Registration failed.', inviteCode: raw.inviteCode });
			return fail(500, { message: 'Something went wrong. Please try again.', inviteCode: raw.inviteCode });
		}

		const created = await db.query.user.findFirst({
			where: (u, { eq: eqFn }) => eqFn(u.email, parsed.data.email)
		});
		await db.update(invite)
			.set({ usedAt: new Date(), usedByUserId: created?.id ?? null })
			.where(eq(invite.code, code));

		return redirect(302, '/');
	}
};
