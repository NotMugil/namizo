import {
	pgTable,
	serial,
	integer,
	real,
	text,
	boolean,
	timestamp,
	index,
	uniqueIndex
} from 'drizzle-orm/pg-core';
import { user } from './auth.schema';

export const invite = pgTable('invite', {
	id: text('id').primaryKey(),
	code: text('code').notNull().unique(),
	note: text('note'),
	createdAt: timestamp('created_at').notNull().defaultNow(),
	expiresAt: timestamp('expires_at'),
	usedAt: timestamp('used_at'),
	usedByUserId: text('used_by_user_id').references(() => user.id, { onDelete: 'set null' }),
	createdByUserId: text('created_by_user_id').references(() => user.id, { onDelete: 'set null' })
});

export const animeMeta = pgTable('anime_meta', {
	id: text('id').primaryKey(),
	title: text('title').notNull(),
	titleJapanese: text('title_japanese'),
	coverImage: text('cover_image'),
	bannerImage: text('banner_image'),
	description: text('description'),
	status: text('status'),
	episodeCount: integer('episode_count'),
	createdAt: timestamp('created_at').notNull().defaultNow(),
	updatedAt: timestamp('updated_at').notNull().defaultNow()
});

export const watchProgress = pgTable(
	'watch_progress',
	{
		id: text('id').primaryKey(),
		userId: text('user_id')
			.notNull()
			.references(() => user.id, { onDelete: 'cascade' }),
		animeId: text('anime_id').notNull(),
		episodeId: text('episode_id').notNull(),
		episodeNumber: integer('episode_number').notNull(),
		position: real('position').notNull().default(0),
		duration: real('duration').notNull().default(0),
		completed: boolean('completed').notNull().default(false),
		updatedAt: timestamp('updated_at').notNull().defaultNow()
	},
	(t) => [
		uniqueIndex('wp_user_anime_ep_idx').on(t.userId, t.animeId, t.episodeNumber),
		index('wp_user_anime_idx').on(t.userId, t.animeId),
		index('wp_user_updated_idx').on(t.userId, t.updatedAt)
	]
);

export const bookmark = pgTable(
	'bookmark',
	{
		id: text('id').primaryKey(),
		userId: text('user_id')
			.notNull()
			.references(() => user.id, { onDelete: 'cascade' }),
		animeId: text('anime_id').notNull(),
		createdAt: timestamp('created_at').notNull().defaultNow()
	},
	(t) => [uniqueIndex('bm_user_anime_idx').on(t.userId, t.animeId)]
);

export const anilistConnection = pgTable('anilist_connection', {
	id: text('id').primaryKey(),
	userId: text('user_id')
		.notNull()
		.unique()
		.references(() => user.id, { onDelete: 'cascade' }),
	anilistId: integer('anilist_id').notNull(),
	anilistUsername: text('anilist_username'),
	// AniList tokens last ~1 year; no refresh token is issued
	accessToken: text('access_token').notNull(),
	tokenType: text('token_type').notNull().default('Bearer'),
	expiresAt: timestamp('expires_at'),
	connectedAt: timestamp('connected_at').notNull().defaultNow()
});

export * from './auth.schema';
