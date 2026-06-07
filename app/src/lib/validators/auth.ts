import { z } from 'zod';

export const loginSchema = z.object({
	email: z.string().email('Enter a valid email address'),
	password: z.string().min(1, 'Password is required')
});

export const registerSchema = z
	.object({
		inviteCode: z.string().min(1, 'An invite code is required'),
		username: z
			.string()
			.min(3, 'Username must be at least 3 characters')
			.max(24, 'Username must be 24 characters or less')
			.regex(/^[a-z0-9_]+$/, 'Username can only contain lowercase letters, numbers, and underscores'),
		displayName: z
			.string()
			.min(2, 'Display name must be at least 2 characters')
			.max(40, 'Display name is too long'),
		email: z.string().email('Enter a valid email address'),
		password: z
			.string()
			.min(8, 'Password must be at least 8 characters')
			.max(128, 'Password is too long'),
		confirmPassword: z.string()
	})
	.refine((d) => d.password === d.confirmPassword, {
		message: 'Passwords do not match',
		path: ['confirmPassword']
	});

export const updateProfileSchema = z.object({
	displayName: z
		.string()
		.min(2, 'Display name must be at least 2 characters')
		.max(40, 'Display name is too long')
		.optional(),
	username: z
		.string()
		.min(3, 'Username must be at least 3 characters')
		.max(24, 'Username must be 24 characters or less')
		.regex(/^[a-z0-9_]+$/, 'Username can only contain lowercase letters, numbers, and underscores')
		.optional(),
	image: z.string().url('Enter a valid image URL').optional().or(z.literal(''))
});

export const changePasswordSchema = z
	.object({
		currentPassword: z.string().min(1, 'Current password is required'),
		newPassword: z.string().min(8, 'Password must be at least 8 characters').max(128),
		confirmNewPassword: z.string()
	})
	.refine((d) => d.newPassword === d.confirmNewPassword, {
		message: 'Passwords do not match',
		path: ['confirmNewPassword']
	});

export type LoginInput = z.infer<typeof loginSchema>;
export type RegisterInput = z.infer<typeof registerSchema>;
