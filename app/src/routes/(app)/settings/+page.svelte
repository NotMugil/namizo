<script lang="ts">
	import { enhance } from '$app/forms';
	import type { ActionData, PageData } from './$types';
	import {
		UserIcon, LockSimpleIcon, PlayCircleIcon, EnvelopeSimpleIcon,
		InfoIcon, PencilSimpleIcon, CopySimpleIcon,
		LinkSimpleIcon, ArrowSquareOutIcon, EyeIcon, EyeSlashIcon,
		ShieldCheckIcon, SpinnerGapIcon, ArrowsClockwiseIcon, XIcon, PlusIcon, DownloadSimpleIcon,
		PuzzlePieceIcon, CheckCircleIcon, StarIcon, MagnifyingGlassIcon
	} from 'phosphor-svelte';
	import { onDestroy, onMount } from 'svelte';
	import { toast } from 'svelte-sonner';
	import { breadcrumb } from '$lib/state.svelte';
	import { librarySave, libraryFetch } from '$lib/api/library';
	import { libraryVersion, playbackPrefs } from '$lib/state.svelte';
	import { invalidateLibraryCache } from '$lib/utils/library';
	import { clearTvdbCache } from '$lib/api/tvdb';

	let { data, form }: { data: PageData; form: ActionData } = $props();
	const user = $derived(data.user);

	let savingProfile  = $state(false);
	let savingPassword = $state(false);
	let showCurrent    = $state(false);
	let showNew        = $state(false);
	let showConfirm    = $state(false);
	let activeSection  = $state('profile');
	let revealedCodes  = $state(new Set<string>());
	const invitesRemaining = $derived(3 - (data.invites?.length ?? 0));

	// ── Invite dialog ──────────────────────────────────────────────────────
	let inviteDialogOpen = $state(false);
	let creatingInvite   = $state(false);

	$effect(() => {
		if (form?.inviteCreated) {
			inviteDialogOpen = false;
			toast.success('Invite created — share the code below.');
		}
	});

	function toggleReveal(id: string) {
		revealedCodes = revealedCodes.has(id)
			? new Set([...revealedCodes].filter(x => x !== id))
			: new Set([...revealedCodes, id]);
	}

	function copyCode(code: string) {
		navigator.clipboard.writeText(code).then(() => {
			toast.success('Invite code copied to clipboard');
		}).catch(() => {
			toast.error('Failed to copy — try manually');
		});
	}

	// ── 2FA ────────────────────────────────────────────────────────────────
	let twoFaEnabled    = $derived(data.twoFactorEnabled ?? false);
	let totpDialogOpen  = $state(false);
	let totpUri         = $state('');
	let backupCodes     = $state<string[]>([]);
	let totpStep        = $state<'password' | 'verify' | 'done'>('password');
	let savingTotp      = $state(false);
	let disableTotpOpen = $state(false);
	let qrDataUrl       = $state('');
	let codeDigits      = $state(['', '', '', '', '', '']);
	const codeValue     = $derived(codeDigits.join(''));

	const totpSecret = $derived(() => {
		if (!totpUri) return '';
		try { return new URL(totpUri).searchParams.get('secret') ?? ''; }
		catch { return ''; }
	});

	// Generate QR code whenever totpUri is set (client-side only)
	$effect(() => {
		if (!totpUri) { qrDataUrl = ''; return; }
		import('qrcode').then(({ default: QRCode }) => {
			QRCode.toDataURL(totpUri, { width: 260, margin: 2, color: { dark: '#000000', light: '#ffffff' } })
				.then(url => { qrDataUrl = url; })
				.catch(() => {});
		});
	});

	function downloadBackupCodes() {
		const content = [
			'Namizo — 2FA Backup Codes',
			'',
			'Keep these in a safe place. Each code can only be used once.',
			'',
			...backupCodes
		].join('\n');
		const blob = new Blob([content], { type: 'text/plain' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = 'namizo-backup-codes.txt';
		a.click();
		URL.revokeObjectURL(url);
	}

	function handleDigitInput(e: Event, idx: number) {
		const input = e.target as HTMLInputElement;
		const val = input.value.replace(/\D/g, '').slice(-1);
		codeDigits = codeDigits.map((d, i) => i === idx ? val : d);
		if (val && idx < 5) {
			(document.getElementById(`totp-d${idx + 1}`) as HTMLInputElement)?.focus();
		}
	}

	function handleDigitKeydown(e: KeyboardEvent, idx: number) {
		if (e.key === 'Backspace' && !codeDigits[idx] && idx > 0) {
			codeDigits = codeDigits.map((d, i) => i === idx - 1 ? '' : d);
			(document.getElementById(`totp-d${idx - 1}`) as HTMLInputElement)?.focus();
		}
	}

	function handleDigitPaste(e: ClipboardEvent) {
		e.preventDefault();
		const text = (e.clipboardData?.getData('text') ?? '').replace(/\D/g, '');
		codeDigits = [...text.slice(0, 6).split(''), ...Array(6).fill('')].slice(0, 6) as string[];
		const lastIdx = Math.min(text.length - 1, 5);
		if (lastIdx >= 0) (document.getElementById(`totp-d${lastIdx}`) as HTMLInputElement)?.focus();
	}

	$effect(() => {
		if (form?.twoFactorEnabled) { totpStep = 'done'; toast.success('Two-factor authentication enabled.'); totpDialogOpen = false; }
		if (form?.twoFactorDisabled) { disableTotpOpen = false; toast.success('Two-factor authentication disabled.'); }
		if (form?.totpUri) {
			totpUri = form.totpUri as string;
			backupCodes = (form.backupCodes as string[]) ?? [];
			codeDigits = ['', '', '', '', '', ''];
			totpStep = 'verify';
		}
	});

	// ── AniList connect / disconnect ───────────────────────────────────────
	let connectingAnilist = $state(false);
	let disconnectAnilistOpen = $state(false);
	let disconnectingAnilist = $state(false);

	$effect(() => {
		if (form?.anilistDisconnected) {
			disconnectAnilistOpen = false;
			toast.success('AniList account disconnected.');
		}
	});

	async function connectAniList() {
		connectingAnilist = true;
		try {
			const res = await fetch('/api/anilist/initiate');
			if (!res.ok) { toast.error('Could not start AniList connection.'); return; }
			const { url }: { url: string } = await res.json();

			try {
				// Use Tauri's opener plugin so the OAuth page opens in the system browser,
				// allowing the user to choose a different AniList account than any one cached
				// in the app webview.
				const { open } = await import('@tauri-apps/plugin-opener');
				await open(url);
			} catch {
				// Fallback for non-Tauri (web browser) context
				window.open(url, '_blank');
			}
		} catch {
			toast.error('Could not start AniList connection.');
		} finally {
			connectingAnilist = false;
		}
	}

	// ── AniList sync ───────────────────────────────────────────────────────
	let syncing = $state(false);

	async function syncAniList() {
		syncing = true;
		try {
			const res = await fetch('/api/anilist/sync');
			if (!res.ok) throw new Error(await res.text());
			const { entries: anilistEntries } = await res.json();

			const existing = await libraryFetch();
			const existingMap = new Map(existing.map((e) => [e.anilist_id, e]));

			let imported = 0, updated = 0, skipped = 0;
			for (const entry of anilistEntries) {
				const local = existingMap.get(entry.anilist_id);
				if (!local) {
					await librarySave(entry);
					imported++;
				} else if (entry.updated_at > local.updated_at) {
					await librarySave({ ...local, ...entry });
					updated++;
				} else {
					skipped++;
				}
			}
			// Invalidate the library snapshot so all AnimeCards re-fetch their status
			invalidateLibraryCache();
			libraryVersion.n++;
			toast.success(`Synced — ${imported} new, ${updated} updated, ${skipped} unchanged`);
		} catch {
			toast.error('Sync failed. Check your AniList connection and try again.');
		} finally {
			syncing = false;
		}
	}

	// ── Cache ─────────────────────────────────────────────────────────────────
	let clearingCache = $state(false);

	async function clearCache() {
		clearingCache = true;
		try {
			await clearTvdbCache();
			invalidateLibraryCache();
			toast.success('Cache cleared. Data will be re-fetched on next load.');
		} catch {
			toast.error('Failed to clear cache. Please try again.');
		} finally {
			clearingCache = false;
		}
	}

	// ── Extensions ────────────────────────────────────────────────────────────
	type ExtCategory = 'all' | 'sources' | 'trackers' | 'subtitles' | 'notifications';
	interface Extension {
		id: string; name: string; description: string; author: string;
		version: string; category: Exclude<ExtCategory, 'all'>;
		stars: number; installed: boolean; official: boolean; lang?: string;
	}
	const EXTENSIONS_DATA: Extension[] = [
		{ id: 'animepahe',    name: 'AnimePahe',              description: 'High-quality anime streaming from AnimePahe with 720p and 1080p sources.', author: 'Namizo',    version: '2.1.0', category: 'sources',       stars: 4.8, installed: true,  official: true,  lang: 'EN' },
		{ id: 'allanime',     name: 'AllAnime',               description: 'Multi-source streaming provider with a wide anime catalogue.',               author: 'Namizo',    version: '1.4.2', category: 'sources',       stars: 4.5, installed: false, official: true,  lang: 'EN' },
		{ id: 'anilist',      name: 'AniList Tracker',        description: 'Sync your watch progress and library with your AniList account.',            author: 'Namizo',    version: '3.0.1', category: 'trackers',      stars: 4.9, installed: true,  official: true },
		{ id: 'mal',          name: 'MyAnimeList',            description: 'Sync your library and progress to MyAnimeList.',                             author: 'Namizo',    version: '1.2.0', category: 'trackers',      stars: 4.3, installed: false, official: true },
		{ id: 'opensubs',     name: 'OpenSubtitles',          description: 'Fetch subtitles automatically from OpenSubtitles for any episode.',          author: 'Namizo',    version: '1.0.5', category: 'subtitles',     stars: 4.1, installed: false, official: true },
		{ id: 'anidap',       name: 'AniDAP',                 description: 'Backup source with alternative streams and download support.',               author: 'community', version: '0.9.3', category: 'sources',       stars: 3.7, installed: false, official: false, lang: 'EN' },
		{ id: 'discord-rpc',  name: 'Discord Rich Presence',  description: "Show what you're watching on Discord with episode info and cover art.",     author: 'community', version: '1.1.0', category: 'notifications', stars: 4.6, installed: false, official: false },
		{ id: 'anizone',      name: 'AniZone',                description: 'Community-run streaming source with dubbed content focus.',                  author: 'community', version: '0.7.1', category: 'sources',       stars: 3.4, installed: false, official: false, lang: 'EN' },
	];
	const EXT_CATEGORIES: { value: ExtCategory; label: string }[] = [
		{ value: 'all',           label: 'All' },
		{ value: 'sources',       label: 'Sources' },
		{ value: 'trackers',      label: 'Trackers' },
		{ value: 'subtitles',     label: 'Subtitles' },
		{ value: 'notifications', label: 'Notifications' },
	];
	let extCategory: ExtCategory = $state('all');
	let extQuery    = $state('');
	let extInstalled: Set<string> = $state(new Set(EXTENSIONS_DATA.filter(e => e.installed).map(e => e.id)));
	const extFiltered = $derived(EXTENSIONS_DATA.filter(e => {
		if (extCategory !== 'all' && e.category !== extCategory) return false;
		if (extQuery.trim()) {
			const q = extQuery.toLowerCase();
			return e.name.toLowerCase().includes(q) || e.description.toLowerCase().includes(q)
		}
		return true;
	}));
	const extVisible = $derived(extFiltered.filter(e => extCategory !== 'all' || extQuery !== '' || !extInstalled.has(e.id)));
	function extToggle(id: string) {
		if (extInstalled.has(id)) extInstalled.delete(id);
		else extInstalled.add(id);
		extInstalled = new Set(extInstalled);
	}

	const NAV = [
		{ id: 'profile',      label: 'Profile',      Icon: UserIcon },
		{ id: 'security',     label: 'Security',     Icon: LockSimpleIcon },
		{ id: 'playback',     label: 'Playback',     Icon: PlayCircleIcon },
		{ id: 'invites',      label: 'Invites',      Icon: EnvelopeSimpleIcon },
		{ id: 'integrations', label: 'Integrations', Icon: LinkSimpleIcon },
		{ id: 'extensions',   label: 'Extensions',   Icon: PuzzlePieceIcon },
		{ id: 'storage',      label: 'Storage',      Icon: ArrowsClockwiseIcon },
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
	let autoplayTrailers = $state(true);

	onMount(() => {
		breadcrumb.items = [{ label: 'Home', href: '/' }, { label: 'Settings' }];
		autoNext = localStorage.getItem('namizo:autoNext') === 'true';
		autoPlay = localStorage.getItem('namizo:autoPlay') === 'true';
		autoplayTrailers = localStorage.getItem('namizo:autoplayTrailers') !== 'false';
	});

	function setAutoNext(v: boolean) { autoNext = v; localStorage.setItem('namizo:autoNext', String(v)); }
	function setAutoPlay(v: boolean) { autoPlay = v; localStorage.setItem('namizo:autoPlay', String(v)); }
	function setAutoplayTrailers(v: boolean) {
		autoplayTrailers = v;
		playbackPrefs.autoplayTrailers = v;
		localStorage.setItem('namizo:autoplayTrailers', String(v));
	}

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
		breadcrumb.items = [];
		if (usernameDebounce) clearTimeout(usernameDebounce);
		if (previewUrl.startsWith('blob:')) URL.revokeObjectURL(previewUrl);
	});
</script>

{#snippet toggle(value: boolean, onChange: (v: boolean) => void)}
	<button type="button" role="switch" aria-checked={value} aria-label="Toggle" onclick={() => onChange(!value)}
		class="relative inline-flex h-5.5 w-10 shrink-0 cursor-pointer rounded-full transition-colors duration-200
		       {value ? 'bg-white' : 'bg-white/20'}">
		<span class="pointer-events-none absolute top-0.5 h-4.5 w-4.5 rounded-full shadow transition-transform duration-200
		             {value ? 'translate-x-4.5 bg-[#111]' : 'translate-x-0.5 bg-white'}"></span>
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

				<!-- Two-factor authentication -->
				<div class="mt-8 pt-6 border-t border-white/6">
					<div class="flex items-center justify-between gap-4">
						<div>
							<div class="flex items-center gap-2 mb-0.5">
								<ShieldCheckIcon size={15} class={twoFaEnabled ? 'text-emerald-400' : 'text-white/30'} />
								<p class="text-[0.88rem] font-medium text-white">Two-factor authentication</p>
							</div>
							<p class="text-[0.75rem] text-white/40">
								{twoFaEnabled ? 'Enabled — your account is protected with TOTP.' : 'Add an extra layer of security with an authenticator app.'}
							</p>
						</div>
						{#if twoFaEnabled}
							<button type="button" onclick={() => (disableTotpOpen = true)}
								class="shrink-0 inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-[0.8rem]
								       border border-red-500/20 bg-red-500/8 text-red-400/80
								       hover:bg-red-500/15 hover:text-red-300 transition-colors">
								Disable 2FA
							</button>
						{:else}
							<button type="button" onclick={() => { totpStep = 'password'; totpDialogOpen = true; }}
								class="shrink-0 inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-[0.8rem]
								       border border-white/12 bg-white/5 text-white/60
								       hover:bg-white/10 hover:text-white transition-colors">
								Enable 2FA
							</button>
						{/if}
					</div>
					{#if form?.totpError}
						<p class="mt-3 text-[0.82rem] text-red-300">{form.totpError}</p>
					{/if}
				</div>
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
					<div class="flex items-center justify-between gap-4 py-4 border-b border-white/6">
						<div>
							<p class="text-[0.88rem] font-medium text-white">Autoplay Trailers</p>
							<p class="text-[0.75rem] text-white/40 mt-0.5">Play trailers automatically when browsing anime cards and the carousel</p>
						</div>
						{@render toggle(autoplayTrailers, setAutoplayTrailers)}
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

				<div class="mb-5 flex flex-col rounded-xl border border-white/8 bg-white/2 divide-y divide-white/6">
					{#if data.invites.length === 0}
						<p class="px-4 py-5 text-[0.82rem] text-white/30 text-center">No invites yet. Create one below.</p>
					{:else}
						{#each data.invites as inv (inv.id)}
							<div class="flex flex-col px-4 pt-3.5 pb-3">
								<!-- Code + status + action buttons row -->
								<div class="flex items-center justify-between gap-3">
									<div class="flex items-center gap-2.5 min-w-0">
										<code class="font-mono text-[0.92rem] font-bold tracking-[0.14em] text-white shrink-0">
											{revealedCodes.has(inv.id) ? inv.code : '••••••••••••'}
										</code>
										{#if inv.usedAt}
											<span class="chip">Used</span>
										{:else}
											<span class="chip chip-accent">Active</span>
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
												class="inline-flex items-center justify-center h-7 w-7 rounded-lg border border-white/10 bg-white/4
												       text-white/40 transition-colors hover:bg-white/8 hover:text-white/70"
												aria-label="Copy invite code">
												<CopySimpleIcon size={13} />
											</button>
										{/if}
									</div>
								</div>
								<!-- Note on second line -->
								{#if inv.note}
									<p class="mt-1 text-[0.72rem] text-white/35 truncate">{inv.note}</p>
								{/if}
							</div>
						{/each}
					{/if}
				</div>

				<button type="button"
					onclick={() => { if (invitesRemaining > 0) inviteDialogOpen = true; }}
					disabled={invitesRemaining <= 0}
					class="inline-flex items-center gap-2 btn-primary rounded-xl py-2.5 text-sm px-5 disabled:opacity-40 disabled:cursor-not-allowed">
					<PlusIcon size={14} weight="bold" />
					{invitesRemaining > 0 ? `Create invite · ${invitesRemaining} remaining` : 'Invite limit reached'}
				</button>
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
							<button type="button" onclick={connectAniList} disabled={connectingAnilist}
								class="shrink-0 inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-sm
								       border border-white/12 bg-white/5 text-white/60
								       hover:bg-white/10 hover:text-white transition-colors disabled:opacity-50">
								<ArrowSquareOutIcon size={14} />
								{connectingAnilist ? 'Opening…' : 'Connect'}
							</button>
						{:else}
							<span class="text-[0.72rem] text-white/25 shrink-0">Set ANILIST_CLIENT_ID in .env</span>
						{/if}
					</div>
					<div class="mt-3 pt-3 border-t border-white/6 flex items-center justify-between gap-4">
						<p class="text-[0.75rem] text-white/30 leading-relaxed">
							{#if data.anilist}
								Connected as <span class="text-white/50">@{data.anilist.anilistUsername}</span>. Sync your AniList library into the local app.
							{:else}
								Connect your AniList account to sync your watchlist and watch progress.
							{/if}
						</p>
						{#if data.anilist}
							<div class="shrink-0 flex items-center gap-2">
								<button type="button" onclick={syncAniList} disabled={syncing}
									class="inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-[0.8rem]
									       border border-white/12 bg-white/5 text-white/60
									       hover:bg-white/10 hover:text-white transition-colors disabled:opacity-50">
									{#if syncing}
										<SpinnerGapIcon size={14} class="animate-spin" />
										Syncing…
									{:else}
										<ArrowsClockwiseIcon size={14} />
										Sync library
									{/if}
								</button>
								<button type="button" onclick={() => (disconnectAnilistOpen = true)}
									class="inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-[0.8rem]
									       border border-red-500/20 bg-red-500/8 text-red-400/80
									       hover:bg-red-500/15 hover:text-red-300 transition-colors">
									Disconnect
								</button>
							</div>
						{/if}
					</div>
				</div>
			</section>

			<div class="border-t border-white/6"></div>

			<!-- EXTENSIONS -->
			<section id="extensions" class="scroll-mt-28 md:scroll-mt-16 py-8">
				<h2 class="text-[0.7rem] font-semibold text-white/35 uppercase tracking-widest mb-1">Extensions</h2>
				<p class="text-[0.78rem] text-white/35 mb-5">Add sources, trackers, and integrations to Namizo.</p>

				<!-- Search + filters -->
				<div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
					<div class="flex gap-1.5 flex-wrap">
						{#each EXT_CATEGORIES as cat}
							<button type="button" onclick={() => (extCategory = cat.value)}
								class="px-3 py-1.5 rounded-full text-[0.78rem] font-medium transition-colors
								       {extCategory === cat.value ? 'bg-white/12 text-white' : 'text-white/40 hover:text-white/70 hover:bg-white/6'}">
								{cat.label}
							</button>
						{/each}
					</div>
					<label class="relative w-full sm:w-56">
						<MagnifyingGlassIcon size={13} class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-white/35" />
						<input type="search" placeholder="Search extensions…" bind:value={extQuery}
							class="h-8 w-full rounded-xl border border-white/10 bg-white/4 pl-8 pr-3
							       text-[0.8rem] text-white/85 outline-none placeholder:text-white/30
							       focus:border-white/20 focus:bg-white/6 transition-colors" />
					</label>
				</div>

				<!-- Installed -->
				{#if extCategory === 'all' && extQuery === ''}
					{@const installedList = EXTENSIONS_DATA.filter(e => extInstalled.has(e.id))}
					{#if installedList.length > 0}
						<div class="mb-6">
							<p class="text-[0.7rem] font-semibold uppercase tracking-widest text-white/30 mb-3">Installed</p>
							<div class="grid gap-2.5 sm:grid-cols-2">
								{#each installedList as ext (ext.id)}
									{@const isInstalled = extInstalled.has(ext.id)}
									<div class="flex items-start justify-between gap-3 rounded-xl border border-white/8 bg-white/2 p-3.5 hover:border-white/14 transition-colors">
										<div class="flex items-center gap-3 min-w-0">
											<div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white/6 border border-white/8">
												<PuzzlePieceIcon size={16} class="text-white/40" weight="duotone" />
											</div>
											<div class="min-w-0">
												<div class="flex items-center gap-1.5">
													<span class="text-[0.84rem] font-medium text-white truncate">{ext.name}</span>
													{#if ext.official}<CheckCircleIcon size={12} class="text-sky-400 shrink-0" weight="fill" />{/if}
												</div>
												<p class="text-[0.72rem] text-white/35 mt-0.5 flex items-center gap-1">
													<StarIcon size={10} weight="fill" class="text-amber-400/70" />{ext.stars.toFixed(1)}
													· {ext.official ? 'Official' : ext.author} · v{ext.version}{#if ext.lang} · {ext.lang}{/if}
												</p>
											</div>
										</div>
										<button type="button" onclick={() => extToggle(ext.id)}
											class="shrink-0 inline-flex items-center gap-1 rounded-lg px-2.5 py-1 text-[0.72rem] font-medium transition-colors
											       {isInstalled ? 'border border-white/10 text-white/45 hover:border-red-500/30 hover:text-red-400 hover:bg-red-500/8' : 'bg-white/10 text-white/75 hover:bg-white/16'}">
											{#if isInstalled}<CheckCircleIcon size={11} weight="fill" />Installed{:else}<DownloadSimpleIcon size={11} />Install{/if}
										</button>
									</div>
								{/each}
							</div>
						</div>
						<p class="text-[0.7rem] font-semibold uppercase tracking-widest text-white/30 mb-3">Available</p>
					{/if}
				{/if}

				<!-- Available / filtered grid -->
				{#if extVisible.length === 0 && (extCategory !== 'all' || extQuery !== '')}
					<div class="flex flex-col items-center justify-center py-12 text-white/25">
						<PuzzlePieceIcon size={32} weight="thin" class="mb-2" />
						<p class="text-sm">No extensions match your search.</p>
					</div>
				{:else}
					<div class="grid gap-2.5 sm:grid-cols-2">
						{#each extVisible as ext (ext.id)}
							{@const isInstalled = extInstalled.has(ext.id)}
							<div class="flex flex-col gap-2.5 rounded-xl border border-white/8 bg-white/2 p-3.5 hover:border-white/14 hover:bg-white/4 transition-colors">
								<div class="flex items-start justify-between gap-3">
									<div class="flex items-center gap-3 min-w-0">
										<div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white/6 border border-white/8">
											<PuzzlePieceIcon size={16} class="text-white/40" weight="duotone" />
										</div>
										<div class="min-w-0">
											<div class="flex items-center gap-1.5">
												<span class="text-[0.84rem] font-medium text-white truncate">{ext.name}</span>
												{#if ext.official}<CheckCircleIcon size={12} class="text-sky-400 shrink-0" weight="fill" />{/if}
											</div>
											<p class="text-[0.72rem] text-white/35 mt-0.5">{ext.official ? 'Official' : ext.author} · v{ext.version}{#if ext.lang} · {ext.lang}{/if}</p>
										</div>
									</div>
									<button type="button" onclick={() => extToggle(ext.id)}
										class="shrink-0 inline-flex items-center gap-1 rounded-lg px-2.5 py-1 text-[0.72rem] font-medium transition-colors
										       {isInstalled ? 'border border-white/10 text-white/45 hover:border-red-500/30 hover:text-red-400 hover:bg-red-500/8' : 'bg-white/10 text-white/75 hover:bg-white/16'}">
										{#if isInstalled}<CheckCircleIcon size={11} weight="fill" />Installed{:else}<DownloadSimpleIcon size={11} />Install{/if}
									</button>
								</div>
								<p class="text-[0.76rem] leading-relaxed text-white/40 line-clamp-2">{ext.description}</p>
								<div class="flex items-center gap-1 text-[0.7rem] text-white/25">
									<StarIcon size={10} weight="fill" class="text-amber-400/70" />
									{ext.stars.toFixed(1)}
									<span class="ml-auto capitalize">{ext.category}</span>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</section>

			<div class="border-t border-white/6"></div>

			<!-- STORAGE -->
			<section id="storage" class="scroll-mt-28 md:scroll-mt-16 py-8">
				<h2 class="text-[0.7rem] font-semibold text-white/35 uppercase tracking-widest mb-1">Storage</h2>
				<p class="text-[0.78rem] text-white/35 mb-5">Manage locally cached data used to speed up the app.</p>

				<div class="rounded-xl border border-white/8 bg-white/2 divide-y divide-white/6">
					<div class="flex items-center justify-between gap-4 p-4">
						<div>
							<p class="text-[0.88rem] font-medium text-white">Episode &amp; background image cache</p>
							<p class="text-[0.75rem] text-white/40 mt-0.5">
								Cached TVDB episode info and background images. Clears automatically after 7 days.
							</p>
						</div>
						<button
							type="button"
							onclick={clearCache}
							disabled={clearingCache}
							class="shrink-0 inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-[0.8rem]
							       border border-white/12 bg-white/5 text-white/60
							       hover:bg-white/10 hover:text-white transition-colors disabled:opacity-50"
						>
							{#if clearingCache}
								<SpinnerGapIcon size={14} class="animate-spin" />
								Clearing…
							{:else}
								<ArrowsClockwiseIcon size={14} />
								Clear cache
							{/if}
						</button>
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

<!-- ── Invite creation dialog ─────────────────────────────────────────────── -->
{#if inviteDialogOpen}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div role="dialog" aria-modal="true" tabindex="-1"
		class="fixed inset-0 z-200 flex items-end sm:items-center justify-center p-4 sm:p-0"
		onkeydown={(e) => { if (e.key === 'Escape') inviteDialogOpen = false; }}>
		<div class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={() => (inviteDialogOpen = false)} role="presentation"></div>
		<div class="relative w-full sm:max-w-sm rounded-2xl border border-white/12 bg-[#0e0e0e] p-5 shadow-2xl">
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-[0.92rem] font-semibold text-white">Create invite</h3>
				<button type="button" onclick={() => (inviteDialogOpen = false)}
					class="text-white/35 hover:text-white/70 transition-colors" aria-label="Close">
					<XIcon size={16} />
				</button>
			</div>

			<form method="post" action="?/createInvite" use:enhance={() => {
				creatingInvite = true;
				return async ({ update }) => { await update(); creatingInvite = false; };
			}} class="flex flex-col gap-3">
				<div class="flex flex-col gap-1.5">
					<label for="inv-note" class="text-[0.75rem] text-white/50">Note <span class="text-white/25">(optional)</span></label>
					<input id="inv-note" type="text" name="note" placeholder="e.g. for John"
						maxlength="80" autocomplete="off"
						class="auth-input text-sm py-2.5" />
				</div>
				<div class="flex flex-col gap-1.5">
					<label for="inv-expires" class="text-[0.75rem] text-white/50">Expires <span class="text-white/25">(optional — leave blank for never)</span></label>
					<input id="inv-expires" type="date" name="expiresAt"
						min={new Date().toISOString().split('T')[0]}
						class="auth-input text-sm py-2.5" />
				</div>
				{#if form?.inviteError}
					<p class="text-[0.8rem] text-red-300">{form.inviteError}</p>
				{/if}
				<div class="flex gap-2.5 mt-1">
					<button type="button" onclick={() => (inviteDialogOpen = false)}
						class="btn-ghost inline flex-1 rounded-xl py-2.5 text-sm">Cancel</button>
					<button type="submit" disabled={creatingInvite}
						class="btn-primary inline flex-1 rounded-xl py-2.5 text-sm disabled:opacity-50">
						{creatingInvite ? 'Creating…' : 'Create invite'}
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<!-- ── 2FA enable dialog ───────────────────────────────────────────────────── -->
{#if totpDialogOpen}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div role="dialog" aria-modal="true" tabindex="-1"
		class="fixed inset-0 z-200 flex items-end sm:items-center justify-center p-4 sm:p-0"
		onkeydown={(e) => { if (e.key === 'Escape') totpDialogOpen = false; }}>
		<div class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={() => (totpDialogOpen = false)} role="presentation"></div>
		<div class="relative w-full sm:max-w-md rounded-2xl border border-white/12 bg-[#0e0e0e] p-5 shadow-2xl">
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-[0.92rem] font-semibold text-white">Enable two-factor authentication</h3>
				<button type="button" onclick={() => (totpDialogOpen = false)}
					class="text-white/35 hover:text-white/70 transition-colors" aria-label="Close">
					<XIcon size={16} />
				</button>
			</div>

			{#if totpStep === 'password'}
				<p class="text-[0.8rem] text-white/45 mb-4">Enter your password to generate a TOTP setup key.</p>
				<form method="post" action="?/getTotpUri" use:enhance={() => {
					savingTotp = true;
					return async ({ update }) => { await update(); savingTotp = false; };
				}} class="flex flex-col gap-3">
					<input type="password" name="password" placeholder="Your password"
						autocomplete="current-password" required
						class="auth-input text-sm py-2.5" />
					<div class="flex gap-2.5">
						<button type="button" onclick={() => (totpDialogOpen = false)}
							class="btn-ghost inline flex-1 rounded-xl py-2.5 text-sm">Cancel</button>
						<button type="submit" disabled={savingTotp}
							class="btn-primary inline flex-1 rounded-xl py-2.5 text-sm disabled:opacity-50">
							{savingTotp ? 'Generating…' : 'Continue'}
						</button>
					</div>
				</form>

			{:else if totpStep === 'verify'}
				<!-- Step 1: QR code + secret -->
				<div class="mb-5">
					<div class="flex items-center gap-2 mb-1.5">
						<span class="inline-flex items-center justify-center h-5 w-5 rounded-full bg-white/12 text-[0.65rem] font-bold text-white shrink-0">1</span>
						<p class="text-[0.88rem] font-medium text-white">Scan QR code</p>
					</div>
					<p class="text-[0.75rem] text-white/40 mb-3 ml-7">Open your authenticator app and scan the code, or enter the secret key manually.</p>

					<div class="rounded-xl border border-white/10 bg-white/4 p-5 flex flex-col items-center gap-4">
						<!-- QR code centered, with enough padding so corners don't clip it -->
						{#if qrDataUrl}
							<img src={qrDataUrl} alt="TOTP QR code" class="h-48 w-48 rounded-xl" />
						{:else}
							<div class="h-48 w-48 rounded-xl bg-white/8 animate-pulse"></div>
						{/if}

						<!-- Secret key for manual entry -->
						<div class="w-full border-t border-white/8 pt-4 text-center">
							<p class="text-[0.72rem] text-white/40 mb-1">Can't scan QR code? Enter this secret manually:</p>
							<code class="block text-[0.85rem] font-mono font-bold text-white/80 tracking-widest my-2 break-all select-all">{totpSecret()}</code>
							<button type="button"
								onclick={() => navigator.clipboard.writeText(totpSecret()).then(() => toast.success('Secret copied'))}
								class="inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-[0.75rem] text-white/50 hover:bg-white/10 hover:text-white/80 transition-colors">
								<CopySimpleIcon size={12} />Copy secret key
							</button>
						</div>
					</div>
				</div>

				<!-- Backup codes -->
				{#if backupCodes.length}
					<div class="rounded-xl border border-amber-500/20 bg-amber-500/5 p-4 mb-5">
						<div class="flex items-start justify-between gap-3 mb-3">
							<p class="text-[0.75rem] text-amber-300/80 font-medium leading-snug">
								Save these backup codes — they can't be shown again. Each code can only be used once.
							</p>
							<button type="button" onclick={downloadBackupCodes}
								class="shrink-0 inline-flex items-center gap-1.5 rounded-lg border border-amber-500/25 bg-amber-500/10
								       px-2.5 py-1.5 text-[0.72rem] text-amber-300/70 hover:bg-amber-500/20 hover:text-amber-200 transition-colors">
								<DownloadSimpleIcon size={12} />
								Download .txt
							</button>
						</div>
						<div class="grid grid-cols-2 gap-x-6 gap-y-1">
							{#each backupCodes as bc}
								<code class="text-[0.78rem] text-white/65 font-mono tracking-wide">{bc}</code>
							{/each}
						</div>
					</div>
				{/if}

				<!-- Step 2: Verify code -->
				<div>
					<div class="flex items-center gap-2 mb-1.5">
						<span class="inline-flex items-center justify-center h-5 w-5 rounded-full bg-white/12 text-[0.65rem] font-bold text-white shrink-0">2</span>
						<p class="text-[0.88rem] font-medium text-white">Get verification code</p>
					</div>
					<p class="text-[0.75rem] text-white/40 mb-3 ml-7">Enter the 6-digit code you see in your authenticator app.</p>

					<form method="post" action="?/enableTwoFactor" use:enhance={() => {
						savingTotp = true;
						return async ({ update }) => { await update({ reset: false }); savingTotp = false; };
					}} class="flex flex-col gap-4 ml-7">
						<input type="hidden" name="code" value={codeValue} />
						<div class="flex gap-2">
							{#each codeDigits as digit, idx}
								<input
									id="totp-d{idx}"
									type="text"
									inputmode="numeric"
									maxlength="2"
									value={digit}
									oninput={(e) => handleDigitInput(e, idx)}
									onkeydown={(e) => handleDigitKeydown(e, idx)}
									onpaste={(e) => handleDigitPaste(e)}
									class="h-11 w-10 rounded-xl border border-white/15 bg-white/5 text-center text-lg font-mono font-bold text-white
									       focus:border-white/40 focus:bg-white/8 focus:outline-none transition-colors"
								/>
							{/each}
						</div>
						<div class="flex gap-2.5">
							<button type="button" onclick={() => (totpStep = 'password')}
								class="btn-ghost inline flex-1 rounded-xl py-2.5 text-sm">Back</button>
							<button type="submit" disabled={savingTotp || codeValue.length < 6}
								class="btn-primary inline flex-1 rounded-xl py-2.5 text-sm disabled:opacity-50">
								{savingTotp ? 'Verifying…' : 'Confirm'}
							</button>
						</div>
					</form>
				</div>
			{/if}
		</div>
	</div>
{/if}

<!-- ── AniList disconnect dialog ──────────────────────────────────────────── -->
{#if disconnectAnilistOpen}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div role="dialog" aria-modal="true" tabindex="-1"
		class="fixed inset-0 z-200 flex items-end sm:items-center justify-center p-4 sm:p-0"
		onkeydown={(e) => { if (e.key === 'Escape') disconnectAnilistOpen = false; }}>
		<div class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={() => (disconnectAnilistOpen = false)} role="presentation"></div>
		<div class="relative w-full sm:max-w-sm rounded-2xl border border-white/12 bg-[#0e0e0e] p-5 shadow-2xl">
			<div class="mb-3.5 flex h-9 w-9 items-center justify-center rounded-full bg-red-500/10">
				<LinkSimpleIcon size={17} class="text-red-400" />
			</div>
			<h3 class="text-[0.92rem] font-semibold text-white mb-1">Disconnect AniList</h3>
			<p class="text-[0.82rem] text-white/45 mb-5">Your local library will remain intact, but sync will stop working until you reconnect.</p>
			<form method="post" action="?/disconnectAnilist" use:enhance={() => {
				disconnectingAnilist = true;
				return async ({ update }) => { await update(); disconnectingAnilist = false; };
			}} class="flex gap-2.5">
				<button type="button" onclick={() => (disconnectAnilistOpen = false)}
					class="btn-ghost inline flex-1 rounded-xl py-2.5 text-sm">Cancel</button>
				<button type="submit" disabled={disconnectingAnilist}
					class="inline flex-1 rounded-xl py-2.5 text-sm font-medium border transition-colors
					       border-red-500/25 bg-red-500/12 text-red-300 hover:bg-red-500/22 disabled:opacity-50">
					{disconnectingAnilist ? 'Disconnecting…' : 'Disconnect'}
				</button>
			</form>
		</div>
	</div>
{/if}

<!-- ── 2FA disable dialog ─────────────────────────────────────────────────── -->
{#if disableTotpOpen}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div role="dialog" aria-modal="true" tabindex="-1"
		class="fixed inset-0 z-200 flex items-end sm:items-center justify-center p-4 sm:p-0"
		onkeydown={(e) => { if (e.key === 'Escape') disableTotpOpen = false; }}>
		<div class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={() => (disableTotpOpen = false)} role="presentation"></div>
		<div class="relative w-full sm:max-w-sm rounded-2xl border border-white/12 bg-[#0e0e0e] p-5 shadow-2xl">
			<div class="mb-3.5 flex h-9 w-9 items-center justify-center rounded-full bg-red-500/10">
				<ShieldCheckIcon size={17} class="text-red-400" />
			</div>
			<h3 class="text-[0.92rem] font-semibold text-white mb-1">Disable two-factor authentication</h3>
			<p class="text-[0.82rem] text-white/45 mb-5">Enter your password to confirm. Your TOTP codes will stop working immediately.</p>
			<form method="post" action="?/disableTwoFactor" use:enhance={() => {
				savingTotp = true;
				return async ({ update }) => { await update(); savingTotp = false; };
			}} class="flex flex-col gap-3">
				<input type="password" name="password" placeholder="Your password"
					autocomplete="current-password" required
					class="auth-input text-sm py-2.5" />
				<div class="flex gap-2.5">
					<button type="button" onclick={() => (disableTotpOpen = false)}
						class="btn-ghost inline flex-1 rounded-xl py-2.5 text-sm">Cancel</button>
					<button type="submit" disabled={savingTotp}
						class="inline flex-1 rounded-xl py-2.5 text-sm font-medium border transition-colors
						       border-red-500/25 bg-red-500/12 text-red-300 hover:bg-red-500/22 disabled:opacity-50">
						{savingTotp ? 'Disabling…' : 'Disable 2FA'}
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}
