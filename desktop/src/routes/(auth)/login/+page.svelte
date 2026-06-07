<script lang="ts">
	import { enhance } from '$app/forms';
	import type { ActionData } from './$types';
	import Logo from '$lib/components/Logo.svelte';

	let { form }: { form: ActionData } = $props();

	let view = $state<'landing' | 'invite' | 'signin' | 'twofa'>('landing');
	let loading = $state(false);
	let showPassword = $state(false);
	let submittedSignIn = $state(false);

	// 2FA digit inputs
	let totpDigits = $state(['', '', '', '', '', '']);
	let totpRefs: HTMLInputElement[] = [];
	const totpCode = $derived(totpDigits.join(''));

	function onTotpInput(i: number, e: Event) {
		const el = e.target as HTMLInputElement;
		const val = el.value.replace(/\D/g, '').slice(-1);
		totpDigits = totpDigits.map((d, idx) => idx === i ? val : d);
		if (val && i < 5) totpRefs[i + 1]?.focus();
	}
	function onTotpKeydown(i: number, e: KeyboardEvent) {
		if (e.key === 'Backspace' && !totpDigits[i] && i > 0) {
			totpDigits = totpDigits.map((d, idx) => idx === i - 1 ? '' : d);
			totpRefs[i - 1]?.focus();
		}
	}
	function onTotpPaste(e: ClipboardEvent) {
		e.preventDefault();
		const text = (e.clipboardData?.getData('text') ?? '').replace(/\D/g, '');
		totpDigits = [...text.slice(0, 6).split(''), ...Array(6).fill('')].slice(0, 6) as string[];
		const last = Math.min(text.length - 1, 5);
		if (last >= 0) totpRefs[last]?.focus();
	}

	let boxes = $state(['', '', '', '', '', '']);
	let boxRefs: HTMLInputElement[] = [];

	const fullCode = $derived(boxes.join(''));
	const codeComplete = $derived(fullCode.length === 6 && boxes.every(b => b !== ''));

	function onBoxInput(i: number, e: Event) {
		const el = e.target as HTMLInputElement;
		const val = el.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
		if (val.length > 1) {
			const chars = val.slice(0, 6);
			chars.split('').forEach((c, offset) => { const idx = i + offset; if (idx < 6) boxes[idx] = c; });
			boxRefs[Math.min(i + chars.length, 5)]?.focus();
			return;
		}
		boxes[i] = val.slice(-1);
		if (val) boxRefs[i + 1]?.focus();
	}

	function onBoxKeyDown(i: number, e: KeyboardEvent) {
		if (e.key === 'Backspace' && !boxes[i] && i > 0) { boxes[i - 1] = ''; boxRefs[i - 1]?.focus(); }
		else if (e.key === 'ArrowLeft' && i > 0) boxRefs[i - 1]?.focus();
		else if (e.key === 'ArrowRight' && i < 5) boxRefs[i + 1]?.focus();
	}

	function onBoxPaste(e: ClipboardEvent) {
		e.preventDefault();
		const text = e.clipboardData?.getData('text').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6) ?? '';
		text.split('').forEach((c, i) => { if (i < 6) boxes[i] = c; });
		boxRefs[Math.min(text.length, 5)]?.focus();
	}

	function resetInvite() { boxes = ['', '', '', '', '', '']; view = 'landing'; }

	$effect(() => {
		if ((form as Record<string, unknown>)?.requires2FA && submittedSignIn) {
			view = 'twofa';
			totpDigits = ['', '', '', '', '', ''];
		}
	});
</script>

<svelte:head><title>Namizo</title></svelte:head>

<div class="w-full max-w-sm flex flex-col items-center">

	{#if view === 'landing'}
		<div class="mb-3"><Logo height={32} class="text-white" /></div>
		<p class="mb-10 text-sm text-white/45 text-center">Anime without compromise.<br/>Members only.</p>

		<div class="w-full flex flex-col gap-3">
			<button class="btn-primary flex items-center justify-between px-5 py-3.5 rounded-xl text-[0.9rem]"
				onclick={() => (view = 'invite')}>
				<span>I have an invite code</span>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
			</button>
		</div>

		<div class="mt-10 border-t border-white/6 w-full pt-6 text-center">
			<p class="text-sm text-white/35">
				Already a member?
				<button onclick={() => (view = 'signin')} class="text-white/60 hover:text-white transition-colors ml-1 underline-offset-2 hover:underline">Sign in</button>
			</p>
		</div>

	{:else if view === 'invite'}
		<div class="mb-6"><Logo height={24} class="text-white" /></div>
		<h2 class="mb-1.5 text-lg font-semibold text-white text-center">Enter your invite code</h2>
		<p class="mb-8 text-sm text-white/40 text-center">6-character code from your invite</p>

		{#if form?.codeError}
			<div class="mb-4 w-full rounded-lg border border-red-500/20 bg-red-500/8 px-4 py-2.5 text-center">
				<p class="text-sm text-red-300">{form.codeError}</p>
			</div>
		{/if}

		<form method="post" action="?/validateCode" class="w-full"
			use:enhance={() => { loading = true; return async ({ update }) => { await update(); loading = false; }; }}>
			<input type="hidden" name="code" value={fullCode} />

			<div class="flex justify-center gap-2.5 mb-6">
				{#each boxes as _, i}
					<input
						bind:this={boxRefs[i]}
						type="text" maxlength="2" inputmode="text" autocomplete="off" spellcheck="false"
						value={boxes[i]}
						oninput={(e) => onBoxInput(i, e)}
						onkeydown={(e) => onBoxKeyDown(i, e)}
						onpaste={onBoxPaste}
						class="w-12 h-14 rounded-xl border border-white/10 bg-white/4
						       text-center text-xl font-semibold text-white tracking-widest
						       focus:border-white/40 focus:bg-white/[0.07] focus:outline-none
						       transition-colors caret-white"
					/>
				{/each}
			</div>

			<button type="submit"
				class="btn-primary rounded-xl py-3.5 text-[0.9rem] flex items-center justify-between px-5"
				disabled={!codeComplete || loading}>
				{#if loading}
					<span>Checking…</span>
					<svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>
				{:else}
					<span>Join Namizo</span>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
				{/if}
			</button>
		</form>

		<button onclick={resetInvite} class="mt-5 text-sm text-white/35 hover:text-white/60 transition-colors flex items-center gap-1.5">
			<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
			Back
		</button>

	{:else if view === 'signin'}
		<div class="mb-7"><Logo height={24} class="text-white" /></div>
		<h2 class="mb-1 text-lg font-semibold text-white">Welcome back</h2>
		<p class="mb-7 text-sm text-white/40">Sign in to continue watching</p>

		{#if form?.signInError}
			<div class="mb-4 w-full rounded-lg border border-red-500/20 bg-red-500/8 px-4 py-2.5">
				<p class="text-sm text-red-300">{form.signInError}</p>
			</div>
		{/if}

		<form method="post" action="?/signInEmail" class="w-full flex flex-col gap-4"
			use:enhance={() => { loading = true; submittedSignIn = true; return async ({ update }) => { await update(); loading = false; }; }}>

			<div class="flex flex-col gap-1.5">
				<label for="email" class="text-xs font-medium text-white/45 uppercase tracking-wider">Email</label>
				<input id="email" name="email" type="email" autocomplete="email" required
					placeholder="you@example.com" class="auth-input" disabled={loading} />
			</div>

			<div class="flex flex-col gap-1.5">
				<label for="password" class="text-xs font-medium text-white/45 uppercase tracking-wider">Password</label>
				<div class="relative">
					<input id="password" name="password" type={showPassword ? 'text' : 'password'}
						autocomplete="current-password" required placeholder="••••••••"
						class="auth-input pr-11" disabled={loading} />
					<button type="button"
						class="absolute right-3 top-1/2 -translate-y-1/2 text-white/30 hover:text-white/55 transition-colors"
						onclick={() => (showPassword = !showPassword)} aria-label="Toggle password">
						{#if showPassword}
							<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
						{:else}
							<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
						{/if}
					</button>
				</div>
			</div>

			<button type="submit"
				class="btn-primary mt-1 rounded-xl py-3.5 text-[0.9rem] flex items-center justify-between px-5"
				disabled={loading}>
				{#if loading}
					<span>Signing in…</span>
					<svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>
				{:else}
					<span>Sign in</span>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
				{/if}
			</button>
		</form>

		<button onclick={() => { view = 'landing'; submittedSignIn = false; }} class="mt-5 text-sm text-white/35 hover:text-white/60 transition-colors flex items-center gap-1.5">
			<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
			Back
		</button>

	{:else if view === 'twofa'}
		<!-- Two-factor authentication step -->
		<div class="mb-7"><Logo height={24} class="text-white" /></div>
		<h2 class="mb-1 text-lg font-semibold text-white">Two-factor authentication</h2>
		<p class="mb-7 text-sm text-white/40 text-center">Enter the 6-digit code from your authenticator app</p>

		{#if form?.signInError}
			<div class="mb-4 w-full rounded-lg border border-red-500/20 bg-red-500/8 px-4 py-2.5">
				<p class="text-sm text-red-300">{form.signInError}</p>
			</div>
		{/if}

		<form method="post" action="?/verifyTotpLogin" class="w-full flex flex-col items-center gap-6"
			use:enhance={() => { loading = true; return async ({ update }) => { await update({ reset: false }); loading = false; }; }}>
			<input type="hidden" name="code" value={totpCode} />
			<div class="flex gap-2">
				{#each totpDigits as digit, i}
					<input
						bind:this={totpRefs[i]}
						type="text" inputmode="numeric" maxlength="1"
						value={digit}
						onfocus={(e) => (e.target as HTMLInputElement).select()}
						oninput={(e) => onTotpInput(i, e)}
						onkeydown={(e) => onTotpKeydown(i, e)}
						onpaste={onTotpPaste}
						class="h-12 w-10 rounded-xl border border-white/10 bg-white/4
						       text-center text-lg font-mono font-bold text-white
						       focus:border-white/40 focus:bg-white/8 focus:outline-none
						       transition-colors"
					/>
				{/each}
			</div>
			<button type="submit"
				class="btn-primary w-full rounded-xl py-3.5 text-[0.9rem] flex items-center justify-between px-5"
				disabled={totpCode.length < 6 || loading}>
				{#if loading}
					<span>Verifying…</span>
					<svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>
				{:else}
					<span>Verify</span>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
				{/if}
			</button>
		</form>

		<button onclick={() => { view = 'signin'; submittedSignIn = false; }} class="mt-5 text-sm text-white/35 hover:text-white/60 transition-colors flex items-center gap-1.5">
			<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
			Back to sign in
		</button>
	{/if}
</div>
