<script lang="ts">
	import { onDestroy, onMount } from 'svelte';
	import { breadcrumb } from '$lib/state.svelte';
	import { PuzzlePieceIcon, DownloadSimpleIcon, CheckCircleIcon, StarIcon, MagnifyingGlassIcon } from 'phosphor-svelte';

	type ExtensionCategory = 'all' | 'sources' | 'trackers' | 'subtitles' | 'notifications';

	interface Extension {
		id: string;
		name: string;
		description: string;
		author: string;
		version: string;
		category: Exclude<ExtensionCategory, 'all'>;
		stars: number;
		installed: boolean;
		official: boolean;
		icon?: string;
		lang?: string;
	}

	const EXTENSIONS: Extension[] = [
		{
			id: 'animepahe',
			name: 'AnimePahe',
			description: 'High-quality anime streaming from AnimePahe with 720p and 1080p sources.',
			author: 'Namizo',
			version: '2.1.0',
			category: 'sources',
			stars: 4.8,
			installed: true,
			official: true,
			lang: 'EN',
		},
		{
			id: 'allanime',
			name: 'AllAnime',
			description: 'Multi-source streaming provider with a wide anime catalogue.',
			author: 'Namizo',
			version: '1.4.2',
			category: 'sources',
			stars: 4.5,
			installed: false,
			official: true,
			lang: 'EN',
		},
		{
			id: 'anilist-tracker',
			name: 'AniList Tracker',
			description: 'Sync your watch progress and library with your AniList account.',
			author: 'Namizo',
			version: '3.0.1',
			category: 'trackers',
			stars: 4.9,
			installed: true,
			official: true,
		},
		{
			id: 'mal-tracker',
			name: 'MyAnimeList',
			description: 'Sync your library and progress to MyAnimeList.',
			author: 'Namizo',
			version: '1.2.0',
			category: 'trackers',
			stars: 4.3,
			installed: false,
			official: true,
		},
		{
			id: 'opensubtitles',
			name: 'OpenSubtitles',
			description: 'Fetch subtitles automatically from OpenSubtitles for any episode.',
			author: 'Namizo',
			version: '1.0.5',
			category: 'subtitles',
			stars: 4.1,
			installed: false,
			official: true,
		},
		{
			id: 'anidap',
			name: 'AniDAP',
			description: 'Backup source with alternative streams and download support.',
			author: 'community',
			version: '0.9.3',
			category: 'sources',
			stars: 3.7,
			installed: false,
			official: false,
			lang: 'EN',
		},
		{
			id: 'discord-rpc',
			name: 'Discord Rich Presence',
			description: "Show what you're watching on Discord with episode info and cover art.",
			author: 'community',
			version: '1.1.0',
			category: 'notifications',
			stars: 4.6,
			installed: false,
			official: false,
		},
		{
			id: 'anizone',
			name: 'AniZone',
			description: 'Community-run streaming source with dubbed content focus.',
			author: 'community',
			version: '0.7.1',
			category: 'sources',
			stars: 3.4,
			installed: false,
			official: false,
			lang: 'EN',
		},
	];

	const CATEGORIES: { value: ExtensionCategory; label: string }[] = [
		{ value: 'all', label: 'All' },
		{ value: 'sources', label: 'Sources' },
		{ value: 'trackers', label: 'Trackers' },
		{ value: 'subtitles', label: 'Subtitles' },
		{ value: 'notifications', label: 'Notifications' },
	];

	let activeCategory: ExtensionCategory = $state('all');
	let query: string = $state('');
	let installed: Set<string> = $state(new Set(EXTENSIONS.filter((e) => e.installed).map((e) => e.id)));

	const filtered = $derived(
		EXTENSIONS.filter((e) => {
			if (activeCategory !== 'all' && e.category !== activeCategory) return false;
			if (query.trim()) {
				const q = query.toLowerCase();
				return e.name.toLowerCase().includes(q) || e.description.toLowerCase().includes(q);
			}
			return true;
		}),
	);

	function toggle(id: string) {
		if (installed.has(id)) installed.delete(id);
		else installed.add(id);
		installed = new Set(installed);
	}

	onMount(() => {
		breadcrumb.items = [{ label: 'Home', href: '/' }, { label: 'Extensions' }];
	});

	onDestroy(() => {
		breadcrumb.items = [];
	});
</script>

{#snippet extensionCard(ext: Extension)}
	{@const isInstalled = installed.has(ext.id)}
	<div class="flex flex-col gap-3 rounded-xl border border-white/8 bg-white/3 p-4 hover:border-white/14 hover:bg-white/5 transition-colors">
		<div class="flex items-start justify-between gap-3">
			<div class="flex items-center gap-3 min-w-0">
				<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/6 border border-white/8">
					<PuzzlePieceIcon size={18} class="text-white/40" weight="duotone" />
				</div>
				<div class="min-w-0">
					<div class="flex items-center gap-1.5">
						<span class="text-sm font-medium text-white truncate">{ext.name}</span>
						{#if ext.official}
							<span title="Official" class="shrink-0">
								<CheckCircleIcon size={13} class="text-sky-400" weight="fill" />
							</span>
						{/if}
					</div>
					<p class="text-xs text-white/35 mt-0.5">
						{ext.official ? 'Official' : ext.author} · v{ext.version}{#if ext.lang} · {ext.lang}{/if}
					</p>
				</div>
			</div>

			<button
				type="button"
				onclick={() => toggle(ext.id)}
				class="shrink-0 inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium transition-colors
				       {isInstalled
				           ? 'border border-white/10 text-white/45 hover:border-red-500/30 hover:text-red-400 hover:bg-red-500/8'
				           : 'bg-white/10 text-white/75 hover:bg-white/16 hover:text-white'}"
			>
				{#if isInstalled}
					<CheckCircleIcon size={12} weight="fill" />
					Installed
				{:else}
					<DownloadSimpleIcon size={12} />
					Install
				{/if}
			</button>
		</div>

		<p class="text-[0.8rem] leading-relaxed text-white/45 line-clamp-2">{ext.description}</p>

		<div class="flex items-center justify-between text-xs text-white/25">
			<span class="flex items-center gap-1">
				<StarIcon size={11} weight="fill" class="text-amber-400/70" />
				{ext.stars.toFixed(1)}
			</span>
			<span class="capitalize">{ext.category}</span>
		</div>
	</div>
{/snippet}

<div class="min-h-screen w-full px-6 pb-16 pt-20 sm:px-8 md:px-10 lg:px-12">

	<!-- Header -->
	<div class="mb-8">
		<div class="flex items-center gap-3 mb-1">
			<PuzzlePieceIcon size={22} class="text-white/50" weight="duotone" />
			<h1 class="text-2xl font-semibold text-white">Extensions</h1>
		</div>
		<p class="text-sm text-white/40 ml-8.5">Add sources, trackers, and integrations to Namizo.</p>
	</div>

	<!-- Search + category filters -->
	<div class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
		<div class="flex gap-1.5 flex-wrap">
			{#each CATEGORIES as cat}
				<button
					type="button"
					onclick={() => (activeCategory = cat.value)}
					class="px-3.5 py-1.5 rounded-full text-[0.8rem] font-medium transition-colors
					       {activeCategory === cat.value
					           ? 'bg-white/12 text-white'
					           : 'text-white/40 hover:text-white/70 hover:bg-white/6'}"
				>
					{cat.label}
				</button>
			{/each}
		</div>

		<label class="relative w-full sm:w-64">
			<MagnifyingGlassIcon size={14} class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-white/35" />
			<input
				type="search"
				placeholder="Search extensions…"
				bind:value={query}
				class="h-9 w-full rounded-xl border border-white/10 bg-white/4 pl-9 pr-3
				       text-sm text-white/85 outline-none placeholder:text-white/30
				       focus:border-white/20 focus:bg-white/6 transition-colors"
			/>
		</label>
	</div>

	<!-- Installed section (only when showing all, no search) -->
	{#if activeCategory === 'all' && query === ''}
		{@const installedList = EXTENSIONS.filter((e) => installed.has(e.id))}
		{#if installedList.length > 0}
			<section class="mb-8">
				<h2 class="mb-3 text-xs font-semibold uppercase tracking-widest text-white/30">Installed</h2>
				<div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
					{#each installedList as ext (ext.id)}
						{@render extensionCard(ext)}
					{/each}
				</div>
			</section>
			<h2 class="mb-3 text-xs font-semibold uppercase tracking-widest text-white/30">Available</h2>
		{/if}
	{/if}

	<!-- All / filtered grid -->
	{#if filtered.filter((e) => activeCategory !== 'all' || query !== '' || !installed.has(e.id)).length === 0 && (activeCategory !== 'all' || query !== '')}
		<div class="flex flex-col items-center justify-center py-20 text-white/25">
			<PuzzlePieceIcon size={36} weight="thin" class="mb-3" />
			<p class="text-sm">No extensions match your search.</p>
		</div>
	{:else}
		{@const visibleList = filtered.filter((e) => activeCategory !== 'all' || query !== '' || !installed.has(e.id))}
		<div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
			{#each visibleList as ext (ext.id)}
				{@render extensionCard(ext)}
			{/each}
		</div>
	{/if}
</div>
