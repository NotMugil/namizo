import { db } from './db';
import { invite } from './db/schema';

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function randomCode(length = 6): string {
	let result = '';
	for (let i = 0; i < length; i++) {
		result += CHARS[Math.floor(Math.random() * CHARS.length)];
	}
	return result;
}

export async function createInvite(options: {
	note?: string;
	expiresAt?: Date;
	code?: string;
	createdByUserId?: string;
} = {}) {
	const code = options.code?.trim().toUpperCase() ?? randomCode();
	const id = crypto.randomUUID();

	await db.insert(invite).values({
		id,
		code,
		note: options.note ?? null,
		expiresAt: options.expiresAt ?? null,
		createdByUserId: options.createdByUserId ?? null
	});

	return { id, code };
}
