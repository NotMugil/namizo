<script lang="ts">
	import { GearIcon, ListIcon, SignOutIcon } from 'phosphor-svelte';
	import Logo from '$lib/components/Logo.svelte';
	import SpotlightSearch from './SpotlightSearch.svelte';
	import { ROUTES } from '$lib/constants/routes';
	import { breadcrumb, signOut } from '$lib/state.svelte';

	let {
		onMenuClick,
		user = null
	}: {
		onMenuClick: () => void;
		user?: { name: string; email: string; image?: string | null; username?: string | null } | null;
	} = $props();

	let scrolled     = $state(false);
	let userMenuOpen = $state(false);

	$effect(() => {
		function handleScroll() { scrolled = window.scrollY > 10; }
		handleScroll();
		window.addEventListener('scroll', handleScroll, { passive: true });
		return () => window.removeEventListener('scroll', handleScroll);
	});

	function avatarInitial(u: typeof user) {
		if (!u) return '?';
		return (u.name ?? u.email).charAt(0).toUpperCase();
	}
</script>

<header
	class="fixed top-0 left-0 right-0 z-50 flex h-14 items-center justify-between px-4 sm:px-5
	       transition-all duration-300
	       {scrolled ? 'bg-black/85 backdrop-blur-[14px] shadow-[0_8px_24px_rgba(0,0,0,0.4)]' : 'bg-transparent'}"
>
	<!-- Logo: mobile only (left) -->
	<a href={ROUTES.HOME} class="sm:hidden shrink-0" aria-label="Namizo home">
		<Logo height={17} class="text-white" />
	</a>

	<!-- Left: hamburger + logo / breadcrumb (desktop only) -->
	<div class="hidden sm:flex items-center gap-3 min-w-0">
		<button
			onclick={onMenuClick}
			class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-white/60
			       hover:text-white hover:bg-white/8 transition-all shrink-0"
			aria-label="Toggle sidebar"
		>
			<ListIcon size={19} weight="regular" />
		</button>

		{#if breadcrumb.items.length > 0}
			<nav class="hidden sm:flex items-center gap-2.5 min-w-0" aria-label="Breadcrumb">
				{#each breadcrumb.items as item, i}
					{#if i > 0}
						<svg width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.8"
							viewBox="0 0 24 24" class="text-white/20 shrink-0">
							<path stroke-linecap="round" stroke-linejoin="round" d="M9 18l6-6-6-6" />
						</svg>
					{/if}
					{#if item.href === '/'}
						<a href="/" aria-label="Home"
							class="text-white/40 hover:text-white/70 transition-colors shrink-0"
						>
							<svg width="15" height="15" fill="currentColor" viewBox="0 0 20 20">
								<path d="M10.707 2.293a1 1 0 0 0-1.414 0l-7 7A1 1 0 0 0 3 11h1v6a1 1 0 0 0 1 1h4v-4h2v4h4a1 1 0 0 0 1-1v-6h1a1 1 0 0 0 .707-1.707l-7-7z"/>
							</svg>
						</a>
					{:else if item.href && i < breadcrumb.items.length - 1}
						<a href={item.href}
							class="text-[13px] text-white/40 hover:text-white/70 transition-colors truncate max-w-[50ch]"
						>{item.label}</a>
					{:else}
						<span class="text-[13px] text-white/85 font-medium truncate max-w-[50ch]">{item.label}</span>
					{/if}
				{/each}
			</nav>
		{:else}
			<a href={ROUTES.HOME} class="hidden sm:block shrink-0" aria-label="Namizo home">
				<Logo height={18} class="text-white" />
			</a>
		{/if}
	</div>

	<!-- Right: search icon (mobile) / pill (desktop) + user (desktop) -->
	<div class="flex items-center gap-2 sm:gap-3">

		<SpotlightSearch />

		<!-- User avatar + dropdown (desktop only) -->
		<div class="hidden sm:block">
			{#if user}
				<div class="relative">
					<button
						onclick={() => { userMenuOpen = !userMenuOpen; }}
						class="inline-flex h-8 w-8 items-center justify-center rounded-full overflow-hidden
						       ring-2 ring-transparent hover:ring-white/25 transition-all"
						aria-label="User menu"
						aria-expanded={userMenuOpen}
					>
						{#if user.image}
							<img src={user.image} alt={user.name} class="h-full w-full object-cover" />
						{:else}
							<span class="flex h-full w-full items-center justify-center bg-white/12 text-white text-xs font-bold">
								{avatarInitial(user)}
							</span>
						{/if}
					</button>

					{#if userMenuOpen}
						<button type="button" class="fixed inset-0 z-40" aria-label="Close"
							onclick={() => (userMenuOpen = false)}></button>
						<div class="absolute right-0 top-10 z-50 w-52 rounded-xl border border-white/8 bg-[#111] shadow-xl py-1.5">
							<div class="px-3.5 py-2.5 border-b border-white/6 mb-1">
								<p class="text-sm font-medium text-white truncate">{user.name}</p>
								{#if user.username}
									<p class="text-xs text-white/40 truncate">@{user.username}</p>
								{:else}
									<p class="text-xs text-white/40 truncate">{user.email}</p>
								{/if}
							</div>
							<a
								href={ROUTES.SETTINGS}
								onclick={() => (userMenuOpen = false)}
								class="flex items-center gap-2.5 px-3.5 py-2 text-sm text-white/55 hover:text-white hover:bg-white/5 transition-colors"
							>
								<GearIcon size={15} />
								Settings
							</a>
							<button
								type="button"
								onclick={() => { userMenuOpen = false; signOut.confirm = true; }}
								class="flex w-full items-center gap-2.5 px-3.5 py-2 text-sm text-red-400/80 hover:text-red-400 hover:bg-red-500/8 transition-colors"
							>
								<SignOutIcon size={15} weight="regular" />
								Sign out
							</button>
						</div>
					{/if}
				</div>
			{:else}
				<a href="/login"
					class="inline-flex h-8 px-3 items-center justify-center rounded-lg border border-white/12 bg-white/6
					       text-[0.82rem] text-white/70 hover:text-white hover:bg-white/10 transition-all">
					Sign in
				</a>
			{/if}
		</div>
	</div>
</header>
