import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { auth } from '$lib/server/auth';
import { APIError } from 'better-auth/api';
import { updateProfileSchema, changePasswordSchema } from '$lib/validators/auth';
import { db } from '$lib/server/db';
import { invite, anilistConnection } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';
import { createInvite } from '$lib/server/invites';
import { env } from '$env/dynamic/private';

const MAX_USER_INVITES = 3;

export const load: PageServerLoad = async (event) => {
	const userId = event.locals.user?.id ?? null;

	const [userInvites, anilist] = await Promise.all([
		userId
			? db.select().from(invite).where(eq(invite.createdByUserId, userId)).orderBy(invite.createdAt)
			: Promise.resolve([]),
		userId
			? db.select().from(anilistConnection).where(eq(anilistConnection.userId, userId)).then(r => r[0] ?? null)
			: Promise.resolve(null)
	]);

	const anilistAuthorizeUrl = env.ANILIST_CLIENT_ID
		? `https://anilist.co/api/v2/oauth/authorize?client_id=${env.ANILIST_CLIENT_ID}&redirect_uri=${encodeURIComponent(env.ANILIST_REDIRECT_URI ?? '')}&response_type=code`
		: null;

	// twoFactorEnabled is added to the user object by the Better Auth twoFactor plugin
	const twoFactorEnabled = (event.locals.user as Record<string, unknown>)?.twoFactorEnabled === true;

	return {
		user: event.locals.user,
		invites: userInvites,
		anilist,
		anilistAuthorizeUrl,
		twoFactorEnabled
	};
};

export const actions: Actions = {
	updateProfile: async (event) => {
		const fd = await event.request.formData();
		const raw = {
			displayName: fd.get('displayName')?.toString() || undefined,
			username:    fd.get('username')?.toString()    || undefined,
			image:       fd.get('image')?.toString()       || undefined
		};
		if (raw.image === '') delete raw.image;

		const parsed = updateProfileSchema.safeParse(raw);
		if (!parsed.success) return fail(400, { profileError: parsed.error.issues[0].message });

		try {
			await auth.api.updateUser({
				body: {
					...(parsed.data.displayName ? { name: parsed.data.displayName, displayName: parsed.data.displayName } : {}),
					...(parsed.data.username    ? { username: parsed.data.username }   : {}),
					...(parsed.data.image       ? { image: parsed.data.image }         : {})
				},
				headers: event.request.headers
			});
		} catch (e) {
			if (e instanceof APIError) return fail(400, { profileError: e.message || 'Update failed' });
			return fail(500, { profileError: 'Something went wrong.' });
		}
		return { profileSuccess: true };
	},

	changePassword: async (event) => {
		const fd = await event.request.formData();
		const raw = {
			currentPassword:    fd.get('currentPassword')?.toString()    ?? '',
			newPassword:        fd.get('newPassword')?.toString()        ?? '',
			confirmNewPassword: fd.get('confirmNewPassword')?.toString() ?? ''
		};

		const parsed = changePasswordSchema.safeParse(raw);
		if (!parsed.success) return fail(400, { passwordError: parsed.error.issues[0].message });

		try {
			await auth.api.changePassword({
				body: { currentPassword: parsed.data.currentPassword, newPassword: parsed.data.newPassword, revokeOtherSessions: false },
				headers: event.request.headers
			});
		} catch (e) {
			if (e instanceof APIError) return fail(400, { passwordError: e.message || 'Password change failed' });
			return fail(500, { passwordError: 'Something went wrong.' });
		}
		return { passwordSuccess: true };
	},

	createInvite: async (event) => {
		const userId = event.locals.user?.id;
		if (!userId) return fail(401, { inviteError: 'Not authenticated.' });

		const fd = await event.request.formData();
		const note = fd.get('note')?.toString().trim() || undefined;
		const expiresAtRaw = fd.get('expiresAt')?.toString();
		const expiresAt = expiresAtRaw ? new Date(expiresAtRaw) : undefined;

		if (expiresAt && isNaN(expiresAt.getTime())) {
			return fail(400, { inviteError: 'Invalid expiry date.' });
		}

		const existing = await db.select({ id: invite.id }).from(invite).where(eq(invite.createdByUserId, userId));
		if (existing.length >= MAX_USER_INVITES)
			return fail(400, { inviteError: `You can only create up to ${MAX_USER_INVITES} invites.` });

		await createInvite({ createdByUserId: userId, note, expiresAt });
		return { inviteCreated: true };
	},

	disconnectAnilist: async (event) => {
		const userId = event.locals.user?.id;
		if (!userId) return fail(401, { anilistError: 'Not authenticated.' });

		await db.delete(anilistConnection).where(eq(anilistConnection.userId, userId));
		return { anilistDisconnected: true };
	},

	// Step 1: enable 2FA — Better Auth generates the secret, stores it, and returns the TOTP URI
	getTotpUri: async (event) => {
		const fd = await event.request.formData();
		const password = fd.get('password')?.toString() ?? '';
		if (!password) return fail(400, { totpError: 'Password is required.' });

		try {
			const result = await auth.api.enableTwoFactor({
				body: { password },
				headers: event.request.headers
			});
			return { totpUri: result.totpURI, backupCodes: result.backupCodes };
		} catch (e) {
			if (e instanceof APIError) return fail(400, { totpError: e.message || 'Failed to set up 2FA.' });
			return fail(500, { totpError: 'Something went wrong.' });
		}
	},

	// Step 2: verify the first TOTP code to confirm the user scanned correctly
	enableTwoFactor: async (event) => {
		const fd = await event.request.formData();
		const code = fd.get('code')?.toString() ?? '';
		if (!code) return fail(400, { totpError: 'Verification code is required.' });

		try {
			await auth.api.verifyTOTP({
				body: { code },
				headers: event.request.headers
			});
		} catch (e) {
			if (e instanceof APIError) return fail(400, { totpError: e.message || 'Invalid code — check your authenticator app.' });
			return fail(500, { totpError: 'Something went wrong.' });
		}
		return { twoFactorEnabled: true };
	},

	disableTwoFactor: async (event) => {
		const fd = await event.request.formData();
		const password = fd.get('password')?.toString() ?? '';
		if (!password) return fail(400, { totpError: 'Password is required.' });

		try {
			await auth.api.disableTwoFactor({
				body: { password },
				headers: event.request.headers
			});
		} catch (e) {
			if (e instanceof APIError) return fail(400, { totpError: e.message || 'Failed to disable 2FA.' });
			return fail(500, { totpError: 'Something went wrong.' });
		}
		return { twoFactorDisabled: true };
	}
};
