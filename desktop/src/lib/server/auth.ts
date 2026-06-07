import { betterAuth } from 'better-auth/minimal';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { sveltekitCookies } from 'better-auth/svelte-kit';
import { twoFactor } from 'better-auth/plugins';
import { env } from '$env/dynamic/private';
import { getRequestEvent } from '$app/server';
import { db } from '$lib/server/db';

export const auth = betterAuth({
	baseURL: env.ORIGIN ?? 'http://localhost:1421',
	secret: env.BETTER_AUTH_SECRET,
	database: drizzleAdapter(db, { provider: 'pg' }),
	emailAndPassword: { enabled: true },
	user: {
		additionalFields: {
			username: {
				type: 'string',
				required: false,
				unique: true,
				input: true
			},
			displayName: {
				type: 'string',
				required: false,
				input: true
			}
		}
	},
	plugins: [
		twoFactor({ issuer: 'Namizo' }),
		sveltekitCookies(getRequestEvent)
	]
});
