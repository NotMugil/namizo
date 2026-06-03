<script lang="ts">
	import { enhance } from '$app/forms';
	import type { ActionData, PageData } from './$types';
	import {
		UserIcon, LockSimpleIcon, PlayCircleIcon, EnvelopeSimpleIcon,
		InfoIcon, PencilSimpleIcon, CopySimpleIcon, CheckIcon as CheckIconPh,
		LinkSimpleIcon, ArrowSquareOutIcon, EyeIcon, EyeSlashIcon
	} from 'phosphor-svelte';
	import { onDestroy, onMount } from 'svelte';

	let { data, form }: { data: PageData; form: ActionData } = $props();
	const user = $derived(data.user);

	let savingProfile  = $state(false);
	let savingPassword = $state(false);
	let showCurrent    = $state(false);
	let showNew        = $state(false);
	let showConfirm    = $state(false);
	let activeSection  = $state('profile');
	let copiedCode     = $state<string | null>(null);
	let revealedCodes  = $state(new Set<string>());
	const invitesRemaining = $derived(3 - (data.invites?.length ?? 0));

	function toggleReveal(id: string) {
		revealedCodes = revealedCodes.has(id)
			? new Set([...revealedCodes].filter(x => x !== id))
			: new Set([...revealedCodes, id]);
	}

	function copyCode(code: string) {
		navigator.clipboard.writeText(code).then(() => {
			copiedCode = code;
			setTimeout(() => { if (copiedCode === code) copiedCode = null; }, 2000);
		});
	}

	const NAV = [
		{ id: 'profile',      label: 'Profile',      Icon: UserIcon },
		{ id: 'security',     label: 'Security',     Icon: LockSimpleIcon },
		{ id: 'playback',     label: 'Playback',     Icon: PlayCircleIcon },
		{ id: 'invites',      label: 'Invites',      Icon: EnvelopeSimpleIcon },
		{ id: 'integrations', label: 'Integrations', Icon: LinkSimpleIcon },
		{ id: 'about',        label: 'About',        Icon: InfoIcon }
	] as const;

	// ── Username uniqueness check ──────────────────────────────────────────
	const currentUsername = $derived(user?.username ?? '');
	let usernameValue  = $state('');
	let usernameStatus = $state<null | 'checking' | 'available' | 'taken' | 'error'>(null);
	let usernameDebounce: ReturnType<typeof setTimeout> | null = null;

	$effect(() => { usernameValue = user?.username ?? ''; });

	$effect(() => {
		const val = usernameValue;
		usernameStatus = null;
		if (!val || val === currentUsername || val.length < 3) return;
		usernameStatus = 'checking';
		if (usernameDebounce) clearTimeout(usernameDebounce);
		usernameDebounce = setTimeout(async () => {
			try {
				const res  = await fetch(`/api/check-username?u=${encodeURIComponent(val)}`);
				const json: { available: boolean | null } = await res.json();
				if (val !== usernameValue) return;
				usernameStatus = json.available === true ? 'available' : json.available === false ? 'taken' : 'error';
			} catch {
				if (val !== usernameValue) return;
				usernameStatus = 'error';
			}
		}, 400);
	});

	// ── Avatar ─────────────────────────────────────────────────────────────
	let imageUrl       = $state('');
	let avatarEditOpen = $state(false);
	let pendingUrl     = $state('');
	let previewUrl     = $state('');
	let fileError      = $state('');

	$effect(() => { imageUrl = user?.image ?? ''; });

	function openAvatarEdit() { pendingUrl = imageUrl; fileError = ''; previewUrl = ''; avatarEditOpen = true; }
	function closeAvatarEdit() {
		if (previewUrl.startsWith('blob:')) URL.revokeObjectURL(previewUrl);
		previewUrl = ''; avatarEditOpen = false;
	}
	function applyAvatar() { imageUrl = pendingUrl; closeAvatarEdit(); }
	function handleFileSelect(e: Event) {
		const file = (e.target as HTMLInputElement).files?.[0];
		fileError = '';
		if (!file) return;
		if (file.size > 5 * 1024 * 1024) { fileError = 'File must be under 5 MB'; return; }
		if (!['image/png', 'image/jpeg', 'image/gif', 'image/webp'].includes(file.type)) {
			fileError = 'Only PNG, JPG, GIF, or WebP are supported'; return;
		}
		// Convert to base64 data URL — stored directly in the DB and
		// works in both web and Tauri without additional file-system plugins.
		const reader = new FileReader();
		reader.onload = (ev) => {
			const result = ev.target?.result;
			if (typeof result === 'string') {
				pendingUrl = result;
				previewUrl = result;
			}
		};
		reader.onerror = () => { fileError = 'Failed to read file. Try again.'; };
		reader.readAsDataURL(file);
	}

	// ── Playback prefs ─────────────────────────────────────────────────────
	let autoNext = $state(false);
	let autoPlay = $state(false);

	onMount(() => {
		autoNext = localStorage.getItem('namizo:autoNext') === 'true';
		autoPlay = localStorage.getItem('namizo:autoPlay') === 'true';
	});

	function setAutoNext(v: boolean) { autoNext = v; localStorage.setItem('namizo:autoNext', String(v)); }
	function setAutoPlay(v: boolean) { autoPlay = v; localStorage.setItem('namizo:autoPlay', String(v)); }

	function scrollTo(id: string) {
		activeSection = id;
		document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
	}

	function initial(name?: string | null, email?: string | null) {
		return ((name ?? email ?? '?').charAt(0)).toUpperCase();
	}

	$effect(() => {
		const observers: IntersectionObserver[] = [];
		for (const { id } of NAV) {
			const el = document.getElementById(id);
			if (!el) continue;
			const obs = new IntersectionObserver(
				([entry]) => { if (entry.isIntersecting) activeSection = id; },
				{ rootMargin: '-30% 0px -60% 0px' }
			);
			obs.observe(el);
			observers.push(obs);
		}
		return () => observers.forEach(o => o.disconnect());
	});

	onDestroy(() => {
		if (usernameDebounce) clearTimeout(usernameDebounce);
		if (previewUrl.startsWith('blob:')) URL.revokeObjectURL(previewUrl);
	});
</script>

{#snippet toggle(value: boolean, onChange: (v: boolean) => void)}
	<button type="button" role="switch" aria-checked={value} aria-label="Toggle" onclick={() => onChange(!value)}
		class="relative inline-flex h-[1.375rem] w-10 shrink-0 cursor-pointer rounded-full transition-colors duration-200
		       {value ? 'bg-white' : 'bg-white/20'}">
		<span class="pointer-events-none absolute top-[2px] h-[18px] w-[18px] rounded-full shadow transition-transform duration-200
		             {value ? 'translate-x-[18px] bg-[#111]' : 'translate-x-[2px] bg-white'}"></span>
	</button>
{/snippet}

<svelte:head><title>Settings — Namizo</title></svelte:head>

<div class="flex min-h-screen pt-14">

	<!-- Left nav sidebar -->
	<aside class="hidden md:flex flex-col shrink-0 w-52 lg:w-56
	               sticky top-14 h-[calc(100vh-3.5rem)] border-r border-white/6 bg-black">
		<div class="px-4 pt-5 pb-3">
			<p class="text-[11px] font-semibold text-white/35 uppercase tracking-widest">Settings</p>
		</div>
		<nav class="px-3 flex flex-col gap-0.5 flex-1">
			{#each NAV as { id, label, Icon }}
				<button onclick={() => scrollTo(id)}
					class="flex items-center gap-3 w-full px-3 py-2.5 rounded-lg text-[0.83rem] text-left transition-colors
					       {activeSection === id ? 'bg-white/10 text-white font-medium' : 'text-white/45 hover:text-white/75 hover:bg-white/5'}">
					<Icon size={15} weight={activeSection === id ? 'fill' : 'regular'} class="shrink-0 opacity-80" />
					{label}
				</button>
			{/each}
		</nav>
	</aside>

	<!-- Mobile tab strip -->
	<div class="md:hidden fixed top-14 left-0 right-0 z-30 flex gap-0.5 px-3 py-2
	             bg-black/90 backdrop-blur-md border-b border-white/6 overflow-x-auto">
		{#each NAV as { id, label }}
			<button onclick={() => scrollTo(id)}
				class="shrink-0 px-3 py-1.5 rounded-lg text-[0.8rem] transition-colors
				       {activeSection === id ? 'bg-white/10 text-white font-medium' : 'text-white/40 hover:text-white/70'}">
				{label}
			</button>
		{/each}
	</div>

	<!-- Main content -->
	<div class="flex-1 overflow-y-auto">
		<div class="max-w-2xl mx-auto px-4 sm:px-8 py-8 mt-10 md:mt-0 space-y-0">

			<!-- PROFILE -->
			<section id="profile" class="scroll-mt-28 md:scroll-mt-16 pb-8">
				<h2 class="text-[0.7rem] font-semibold text-white/35 uppercase tracking-widest mb-5 pt-2">Profile</h2>

				{#if form?.profileError}
					<div class="mb-4 rounded-lg border border-red-500/20 bg-red-500/8 px-4 py-2.5">
						<p class="text-sm text-red-300">{form.profileError}</p>
					</div>
				{/if}
				{#if form?.profileSuccess}
					<div class="mb-4 rounded-lg border border-white/10 bg-white/4 px-4 py-2.5">
						<p class="text-sm text-white/65">Profile updated.</p>
					</div>
				{/if}

				<form method="post" action="?/updateProfile" class="flex flex-col gap-0"
					use:enhance={() => { savingProfile = true; return async ({ update }) => { await update(); savingProfile = false; }; }}>

					<input type="hidden" name="image" bind:value={imageUrl} />

					<!-- Avatar -->
					<div class="flex items-center justify-between gap-4 py-4 border-b border-white/6">
						<div>
							<p class="text-[0.88rem] font-medium text-white">Profile Photo</p>
							<p class="text-[0.75rem] text-white/40 mt-0.5">Click to change</p>
						</div>
						<button type="button" onclick={openAvatarEdit}
							class="relative h-11 w-11 rounded-full overflow-hidden ring-1 ring-white/12 bg-white/8 shrink-0 group">
							{#if imageUrl}
								<img src={imageUrl} alt={user?.name} class="h-full w-full object-cover" />
							{:else}
								<span class="flex h-full w-full items-center justify-center text-lg font-bold text-white">
									{initial(user?.name, user?.email)}
								</span>
							{/if}
							<span class="absolute inset-0 flex items-center justify-center rounded-full
							             bg-black/0 group-hover:bg-black/55 transition-colors">
								<PencilSimpleIcon size={14} class="text-transparent group-hover:text-white transition-colors" />
							</span>
						</button>
					</div>

					<!-- Display name -->
					<div class="flex items-center justify-between gap-4 py-4 border-b border-white/6">
						<div class="min-w-0 shrink-0 w-36">
							<p class="text-[0.88rem] font-medium text-white">Display Name</p>
							<p class="text-[0.75rem] text-white/40 mt-0.5">Your public name</p>
						</div>
						<input name="displayName" type="text" value={user?.name ?? ''} maxlength="40" placeholder="Your name"
							class="auth-input inline flex-1 min-w-0 text-sm py-2" disabled={savingProfile} />
					</div>

					<!-- Username -->
					<div class="flex items-start justify-between gap-4 py-4 border-b border-white/6">
						<div class="min-w-0 shrink-0 w-36">
							<p class="text-[0.88rem] font-medium text-white">Username</p>
							<p class="text-[0.75rem] text-white/40 mt-0.5">Unique @handle</p>
						</div>
						<div class="flex flex-col gap-1 flex-1 min-w-0">
							<div class="relative">
								<span class="absolute left-3 top-1/2 -translate-y-1/2 text-white/25 text-sm select-none">@</span>
								<input name="username" type="text" bind:value={usernameValue}
									minlength="3" maxlength="24" placeholder="yourhandle"
									class="auth-input inline w-full pl-7 text-sm py-2" disabled={savingProfile} />
							</div>
							{#if usernameStatus === 'checking'}
								<p class="text-[11px] text-white/35">Checking…</p>
							{:else if usernameStatus === 'available'}
								<p class="text-[11px] text-emerald-400/70">Username available</p>
							{:else if usernameStatus === 'taken'}
								<p class="text-[11px] text-red-400/70">Username already taken</p>
							{:else if usernameStatus === 'error'}
								<p class="text-[11px] text-white/30">Could not check availability</p>
							{/if}
						</div>
					</div>

					<!-- Email (read-only) -->
					<div class="flex items-center justify-between gap-4 py-4 border-b border-white/6">
						<div class="min-w-0 shrink-0 w-36">
							<p class="text-[0.88rem] font-medium text-white">Email</p>
							<p class="text-[0.75rem] text-white/40 mt-0.5">Cannot be changed</p>
						</div>
						<p class="text-sm text-white/35 flex-1 text-right truncate">{user?.email ?? '—'}</p>
					</div>

					<div class="pt-4">
						<button type="submit" class="btn-primary inline rounded-xl py-2.5 text-sm px-6"
							disabled={savingProfile || usernameStatus === 'taken'}>
							{savingProfile ? 'Saving…' : 'Save profile'}
						</button>
					</div>
				</form>
			</section>

			<div class="border-t border-white/6"></div>

			<!-- SECURITY -->
			<section id="security" class="scroll-mt-28 md:scroll-mt-16 py-8">
				<h2 class="text-[0.7rem] font-semibold text-white/35 uppercase tracking-widest mb-5">Security</h2>

				{#if form?.passwordError}
					<div class="mb-4 rounded-lg border border-red-500/20 bg-red-500/8 px-4 py-2.5">
						<p class="text-sm text-red-300">{form.passwordError}</p>
					</div>
				{/if}
				{#if form?.passwordSuccess}
					<div class="mb-4 rounded-lg border border-white/10 bg-white/4 px-4 py-2.5">
						<p class="text-sm text-white/65">Password changed.</p>
					</div>
				{/if}

				<form method="post" action="?/changePassword" class="flex flex-col gap-0"
					use:enhance={() => { savingPassword = true; return async ({ update }) => { await update(); savingPassword = false; }; }}>
					{#each [
						{ id: 'currentPassword',   label: 'Current password',    desc: 'Your existing password',     show: showCurrent, toggle: () => (showCurrent = !showCurrent), ac: 'current-password' as const },
						{ id: 'newPassword',        label: 'New password',        desc: 'At least 8 characters',      show: showNew,     toggle: () => (showNew = !showNew),           ac: 'new-password' as const },
						{ id: 'confirmNewPassword', label: 'Confirm new password',desc: 'Re-enter your new password', show: showConfirm, toggle: () => (showConfirm = !showConfirm),   ac: 'new-password' as const }
					] as f}
						<div class="flex items-center justify-between gap-4 py-4 border-b border-white/6">
							<div class="min-w-0 shrink-0 w-36">
								<p class="text-[0.88rem] font-medium text-white">{f.label}</p>
								<p class="text-[0.75rem] text-white/40 mt-0.5">{f.desc}</p>
							</div>
							<div class="relative flex-1 min-w-0">
								<input id={f.id} name={f.id} type={f.show ? 'text' : 'password'}
									autocomplete={f.ac} required placeholder="••••••••"
									class="auth-input w-full pr-11 text-sm py-2" disabled={savingPassword} />
								<button type="button" onclick={f.toggle}
									class="absolute right-3 top-1/2 -translate-y-1/2 text-white/25 hover:text-white/55 transition-colors">
									{#if f.show}
										<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
									{:else}
										<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
									{/if}
								</button>
							</div>
						</div>
					{/each}
					<div class="pt-4">
						<button type="submit" class="btn-primary inline rounded-xl py-2.5 text-sm px-6" disabled={savingPassword}>
							{savingPassword ? 'Updating…' : 'Update password'}
						</button>
					</div>
				</form>
			</section>

			<div class="border-t border-white/6"></div>

			<!-- PLAYBACK -->
			<section id="playback" class="scroll-mt-28 md:scroll-mt-16 py-8">
				<h2 class="text-[0.7rem] font-semibold text-white/35 uppercase tracking-widest mb-5">Playback</h2>
				<div class="flex flex-col gap-0">
					<div class="flex items-center justify-between gap-4 py-4 border-b border-white/6">
						<div>
							<p class="text-[0.88rem] font-medium text-white">Auto Next Episode</p>
							<p class="text-[0.75rem] text-white/40 mt-0.5">Automatically play the next episode when current ends</p>
						</div>
						{@render toggle(autoNext, setAutoNext)}
					</div>
					<div class="flex items-center justify-between gap-4 py-4 border-b border-white/6">
						<div>
							<p class="text-[0.88rem] font-medium text-white">Auto Play</p>
							<p class="text-[0.75rem] text-white/40 mt-0.5">Start playing automatically when opening an episode</p>
						</div>
						{@render toggle(autoPlay, setAutoPlay)}
					</div>
				</div>
			</section>

			<div class="border-t border-white/6"></div>

			<!-- INVITES -->
			<section id="invites" class="scroll-mt-28 md:scroll-mt-16 py-8">
				<h2 class="text-[0.7rem] font-semibold text-white/35 uppercase tracking-widest mb-1">Invites</h2>
				<p class="text-[0.78rem] text-white/35 mb-5">Share access with up to 3 people. Each invite can only be used once.</p>

				{#if form?.inviteError}
					<div class="mb-4 rounded-lg border border-red-500/20 bg-red-500/8 px-4 py-2.5">
						<p class="text-sm text-red-300">{form.inviteError}</p>
					</div>
				{/if}
				{#if form?.inviteCreated}
					<div class="mb-4 rounded-lg border border-white/10 bg-white/4 px-4 py-2.5">
						<p class="text-sm text-white/65">Invite created — share the code below.</p>
					</div>
				{/if}

				<div class="mb-5 flex flex-col rounded-xl border border-white/8 bg-white/[0.02] divide-y divide-white/6">
					{#if data.invites.length === 0}
						<p class="px-4 py-5 text-[0.82rem] text-white/30 text-center">No invites yet. Create one below.</p>
					{:else}
						{#each data.invites as inv (inv.id)}
							<div class="flex items-center justify-between gap-3 px-4 py-3.5">
								<div class="flex items-center gap-2.5 min-w-0">
									<code class="font-mono text-[0.92rem] font-bold tracking-[0.14em] text-white shrink-0">
										{revealedCodes.has(inv.id) ? inv.code : '••••••••••••'}
									</code>
									{#if inv.usedAt}
										<span class="chip">Used</span>
									{:else}
										<span class="chip chip-accent">Active</span>
									{/if}
									{#if inv.note}
										<span class="text-[0.72rem] text-white/30 truncate max-w-[12ch]">{inv.note}</span>
									{/if}
								</div>
								<div class="flex items-center gap-2 shrink-0">
									<span class="text-[0.72rem] text-white/25 tabular-nums">
										{new Date(inv.createdAt).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
									</span>
									<button type="button" onclick={() => toggleReveal(inv.id)}
										class="inline-flex items-center justify-center h-7 w-7 rounded-lg border border-white/10 bg-white/4
										       text-white/40 transition-colors hover:bg-white/8 hover:text-white/70"
										aria-label={revealedCodes.has(inv.id) ? 'Hide code' : 'Reveal code'}>
										{#if revealedCodes.has(inv.id)}
											<EyeSlashIcon size={13} />
										{:else}
											<EyeIcon size={13} />
										{/if}
									</button>
									{#if !inv.usedAt}
										<button type="button" onclick={() => copyCode(inv.code)}
											class="inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/4
											       px-2.5 py-1 text-[0.72rem] text-white/55 transition-colors
											       hover:border-white/18 hover:bg-white/8 hover:text-white/80">
											{#if copiedCode === inv.code}
												<CheckIconPh size={11} weight="bold" class="text-emerald-400" />
												<span class="text-emerald-400">Copied</span>
											{:else}
												<CopySimpleIcon size={11} />
												Copy
											{/if}
										</button>
									{/if}
								</div>
							</div>
						{/each}
					{/if}
				</div>

				<form method="post" action="?/createInvite" use:enhance class="flex flex-col gap-3">
					<div class="flex gap-2">
						<input
							type="text"
							name="note"
							placeholder="Note (optional) — e.g. for John"
							maxlength="80"
							class="flex-1 rounded-xl border border-white/10 bg-white/5 px-3.5 py-2.5
							       text-[0.83rem] text-white placeholder:text-white/25
							       focus:border-white/20 focus:outline-none transition-colors"
						/>
						<button type="submit" disabled={invitesRemaining <= 0}
							class="btn-primary inline rounded-xl py-2.5 text-sm px-5 disabled:opacity-40 disabled:cursor-not-allowed shrink-0">
							{invitesRemaining > 0 ? `Create · ${invitesRemaining} left` : 'Limit reached'}
						</button>
					</div>
				</form>
			</section>

			<div class="border-t border-white/6"></div>

			<!-- INTEGRATIONS -->
			<section id="integrations" class="scroll-mt-28 md:scroll-mt-16 py-8">
				<h2 class="text-[0.7rem] font-semibold text-white/35 uppercase tracking-widest mb-1">Integrations</h2>
				<p class="text-[0.78rem] text-white/35 mb-5">Connect third-party services to sync your watchlist and progress.</p>

				<!-- AniList -->
				<div class="rounded-xl border border-white/8 bg-white/2 p-4">
					<div class="flex items-center justify-between gap-4">
						<div class="flex items-center gap-3 min-w-0">
							<!-- AniList logo mark -->
							<div class="h-10 w-10 shrink-0 rounded-xl overflow-hidden bg-[#02a9ff]/10 border border-[#02a9ff]/20 flex items-center justify-center">
								<img
									src="https://anilist.co/img/icons/icon.svg"
									alt="AniList"
									width="22"
									height="22"
								/>
							</div>
							<div class="min-w-0">
								<p class="text-[0.88rem] font-medium text-white">AniList</p>
								<p class="text-[0.75rem] text-white/40 mt-0.5">Sync watchlist, ratings and watch progress</p>
							</div>
						</div>
						{#if data.anilist}
							<div class="shrink-0 flex items-center gap-2">
								<span class="text-[0.75rem] text-emerald-400/80">@{data.anilist.anilistUsername}</span>
								<span class="inline-flex items-center rounded-full px-2 py-0.5 text-[11px] bg-emerald-500/10 border border-emerald-500/20 text-emerald-400">Connected</span>
							</div>
						{:else if data.anilistAuthorizeUrl}
							<a href={data.anilistAuthorizeUrl}
								class="shrink-0 inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-sm
								       border border-white/12 bg-white/5 text-white/60
								       hover:bg-white/10 hover:text-white transition-colors">
								<ArrowSquareOutIcon size={14} />
								Connect
							</a>
						{:else}
							<span class="text-[0.72rem] text-white/25 shrink-0">Set ANILIST_CLIENT_ID in .env</span>
						{/if}
					</div>
					<div class="mt-3 pt-3 border-t border-white/6">
						<p class="text-[0.75rem] text-white/30 leading-relaxed">
							{#if data.anilist}
								Connected as <span class="text-white/50">@{data.anilist.anilistUsername}</span>. Your AniList library is available for syncing.
							{:else}
								Connect your AniList account to sync your watchlist and watch progress. Uses the secure Authorization Code flow.
							{/if}
						</p>
					</div>
				</div>
			</section>

			<div class="border-t border-white/6"></div>

			<!-- ABOUT -->
			<section id="about" class="scroll-mt-28 md:scroll-mt-16 py-8 pb-16">
				<h2 class="text-[0.7rem] font-semibold text-white/35 uppercase tracking-widest mb-5">About</h2>
				<div class="flex flex-col gap-0">
					{#each [
						{ label: 'Version',      value: '0.1.0' },
						{ label: 'Anime data',   value: 'AniList GraphQL API' },
						{ label: 'Episode data', value: 'MyAnimeList / Jikan + TVDB' },
						{ label: 'Streaming',    value: 'HLS via hls.js' },
						{ label: 'Access',       value: 'Invite-only' }
					] as row}
						<div class="flex items-center justify-between gap-4 py-3.5 border-b border-white/6 last:border-0">
							<p class="text-[0.88rem] text-white/55">{row.label}</p>
							<p class="text-[0.88rem] text-white/80 text-right">{row.value}</p>
						</div>
					{/each}
				</div>
			</section>

		</div>
	</div>
</div>

<!-- Avatar edit modal -->
{#if avatarEditOpen}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div role="dialog" aria-modal="true" tabindex="-1"
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/65 backdrop-blur-sm p-4"
		onclick={closeAvatarEdit}
		onkeydown={(e) => { if (e.key === 'Escape') closeAvatarEdit(); }}>
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="w-full max-w-sm rounded-2xl border border-white/12 bg-[#0e0e0e] p-5 shadow-2xl"
			onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-sm font-semibold text-white">Edit Profile Photo</h3>
				<button type="button" onclick={closeAvatarEdit} aria-label="Close" class="text-white/35 hover:text-white/70 transition-colors">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">
						<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>

			<div class="flex justify-center mb-5">
				<div class="h-20 w-20 rounded-full overflow-hidden ring-2 ring-white/10 bg-white/8">
					{#if previewUrl || pendingUrl}
						<img src={previewUrl || pendingUrl} alt="Preview" class="h-full w-full object-cover" />
					{:else}
						<span class="flex h-full w-full items-center justify-center text-2xl font-bold text-white">
							{initial(user?.name, user?.email)}
						</span>
					{/if}
				</div>
			</div>

			<div class="mb-4">
				<p class="text-xs font-medium text-white/40 uppercase tracking-wider mb-2">Select from device</p>
				<label class="relative block cursor-pointer">
					<input type="file" accept="image/png, image/jpeg, image/gif" onchange={handleFileSelect}
						class="absolute inset-0 opacity-0 w-full h-full cursor-pointer" />
					<div class="auth-input flex items-center gap-2 text-sm text-white/55 cursor-pointer">
						<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="shrink-0">
							<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
							<polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>
						</svg>
						{previewUrl ? 'Change file…' : 'Choose file…'}
					</div>
				</label>
				{#if fileError}
					<p class="text-[11px] text-red-400/75 mt-1.5">{fileError}</p>
				{:else}
					<p class="text-[11px] text-white/25 mt-1.5">PNG, JPG, or GIF · max 10 MB</p>
				{/if}
			</div>

			<div class="flex items-center gap-3 mb-4">
				<div class="flex-1 h-px bg-white/8"></div>
				<span class="text-[11px] text-white/25 shrink-0">or paste URL</span>
				<div class="flex-1 h-px bg-white/8"></div>
			</div>

			<div class="mb-5">
				<input type="url" bind:value={pendingUrl} placeholder="https://example.com/avatar.jpg" class="auth-input text-sm" />
			</div>

			<div class="flex gap-2.5">
				<button type="button" onclick={closeAvatarEdit} class="btn-ghost inline flex-1 py-2.5 text-sm rounded-xl">Cancel</button>
				<button type="button" onclick={applyAvatar} class="btn-primary inline flex-1 py-2.5 text-sm rounded-xl">Apply</button>
			</div>
		</div>
	</div>
{/if}
