<script lang="ts">
	import { enhance } from '$app/forms';
	import type { ActionData, PageData } from './$types';
	import Logo from '$lib/components/Logo.svelte';

	let { form, data }: { form: ActionData; data: PageData } = $props();

	let loading = $state(false);
	let showPassword = $state(false);
	let showConfirm = $state(false);
</script>

<svelte:head><title>Create account — Namizo</title></svelte:head>

<div class="w-full max-w-sm flex flex-col items-center">
	<div class="mb-6"><Logo height={24} class="text-white" /></div>

	<h1 class="mb-1 text-lg font-semibold text-white">Create your account</h1>
	<p class="mb-7 text-sm text-white/40">Your invite code has been accepted</p>

	{#if form?.message}
		<div class="mb-4 w-full rounded-lg border border-red-500/20 bg-red-500/8 px-4 py-2.5">
			<p class="text-sm text-red-300">{form.message}</p>
		</div>
	{/if}

	<form method="post" action="?/signUpEmail" class="w-full flex flex-col gap-3.5"
		use:enhance={() => { loading = true; return async ({ update }) => { await update(); loading = false; }; }}>

		<input type="hidden" name="inviteCode" value={form?.inviteCode ?? data.prefillCode} />

		<div class="flex flex-col gap-1.5">
			<label for="username" class="text-xs font-medium text-white/45 uppercase tracking-wider">Username</label>
			<div class="relative">
				<span class="absolute left-3 top-1/2 -translate-y-1/2 text-white/30 text-sm font-medium select-none">@</span>
				<input id="username" name="username" type="text" autocomplete="username"
					required minlength="3" maxlength="24" placeholder="yourhandle"
					class="auth-input pl-7" disabled={loading} />
			</div>
			<p class="text-[11px] text-white/30">Lowercase letters, numbers, underscores only</p>
		</div>

		<div class="flex flex-col gap-1.5">
			<label for="displayName" class="text-xs font-medium text-white/45 uppercase tracking-wider">Display name</label>
			<input id="displayName" name="displayName" type="text" autocomplete="name"
				required minlength="2" maxlength="40" placeholder="Your Name"
				class="auth-input" disabled={loading} />
		</div>

		<div class="flex flex-col gap-1.5">
			<label for="email" class="text-xs font-medium text-white/45 uppercase tracking-wider">Email</label>
			<input id="email" name="email" type="email" autocomplete="email"
				required placeholder="you@example.com" class="auth-input" disabled={loading} />
		</div>

		<div class="flex flex-col gap-1.5">
			<label for="password" class="text-xs font-medium text-white/45 uppercase tracking-wider">Password</label>
			<div class="relative">
				<input id="password" name="password" type={showPassword ? 'text' : 'password'}
					autocomplete="new-password" required minlength="8" placeholder="Min. 8 characters"
					class="auth-input pr-11" disabled={loading} />
				<button type="button"
					class="absolute right-3 top-1/2 -translate-y-1/2 text-white/30 hover:text-white/55 transition-colors"
					onclick={() => (showPassword = !showPassword)} aria-label="Toggle">
					{#if showPassword}
						<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
					{:else}
						<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
					{/if}
				</button>
			</div>
		</div>

		<div class="flex flex-col gap-1.5">
			<label for="confirmPassword" class="text-xs font-medium text-white/45 uppercase tracking-wider">Confirm password</label>
			<div class="relative">
				<input id="confirmPassword" name="confirmPassword" type={showConfirm ? 'text' : 'password'}
					autocomplete="new-password" required placeholder="Repeat password"
					class="auth-input pr-11" disabled={loading} />
				<button type="button"
					class="absolute right-3 top-1/2 -translate-y-1/2 text-white/30 hover:text-white/55 transition-colors"
					onclick={() => (showConfirm = !showConfirm)} aria-label="Toggle">
					{#if showConfirm}
						<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
					{:else}
						<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
					{/if}
				</button>
			</div>
		</div>

		<button type="submit"
			class="btn-primary mt-1.5 rounded-xl py-3.5 text-[0.9rem] flex items-center justify-between px-5"
			disabled={loading}>
			{#if loading}
				<span>Creating account…</span>
				<svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>
			{:else}
				<span>Create account</span>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
			{/if}
		</button>
	</form>

	<p class="mt-6 text-center text-sm text-white/30">
		Already a member?
		<a href="/login" class="text-white/55 hover:text-white transition-colors ml-1">Sign in</a>
	</p>
</div>
