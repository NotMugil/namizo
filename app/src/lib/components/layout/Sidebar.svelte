<script lang="ts">
	import { page } from '$app/state';
	import { HouseIcon, CompassIcon, BookmarkIcon, CalendarIcon, SignOutIcon } from 'phosphor-svelte';
	import { ROUTES } from '$lib/constants/routes';
	import { sidebar, signOut } from '$lib/state.svelte';
	import Logo from '$lib/components/shared/Logo.svelte';

	let {
		user = null
	}: {
		user?: { name: string; email: string; image?: string | null; username?: string | null } | null;
	} = $props();

	const navLinks = [
		{ href: ROUTES.HOME,     label: 'Home',     icon: HouseIcon },
		{ href: ROUTES.DISCOVER, label: 'Discover', icon: CompassIcon },
		{ href: ROUTES.LIBRARY,  label: 'Library',  icon: BookmarkIcon },
		{ href: ROUTES.SCHEDULE, label: 'Schedule', icon: CalendarIcon },
	];

	function close() { sidebar.open = false; }

	function initial(u: typeof user) {
		if (!u) return '?';
		return (u.name ?? u.email).charAt(0).toUpperCase();
	}
</script>

<aside class="w-64 h-full flex flex-col bg-[#0a0a0a] border-r border-white/6">
	<!-- Logo -->
	<div class="flex items-center px-4 h-14 border-b border-white/6 shrink-0">
		<a href={ROUTES.HOME} onclick={close} aria-label="Namizo home">
			<Logo height={20} class="text-white" />
		</a>
	</div>

	<!-- Navigation -->
	<nav class="flex flex-col gap-0.5 p-3 flex-1 overflow-y-auto">
		{#each navLinks as { href, label, icon: Icon }}
			{@const active = page.url.pathname === href}
			<a
				{href}
				onclick={close}
				class="flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors
				       {active ? 'bg-white/8 text-white font-medium' : 'text-white/45 hover:bg-white/5 hover:text-white/80'}"
				aria-current={active ? 'page' : undefined}
			>
				<Icon size={18} weight={active ? 'fill' : 'regular'} />
				{label}
			</a>
		{/each}
	</nav>

	<!-- User card at bottom -->
	{#if user}
		<div class="p-3 border-t border-white/6 shrink-0">
			<a
				href={ROUTES.SETTINGS}
				onclick={close}
				class="flex items-center gap-2.5 px-3 py-2.5 rounded-lg hover:bg-white/5 transition-colors group"
				aria-label="Open settings"
			>
				<div class="h-8 w-8 rounded-full overflow-hidden shrink-0 ring-1 ring-white/10">
					{#if user.image}
						<img src={user.image} alt={user.name} class="h-full w-full object-cover" />
					{:else}
						<span class="flex h-full w-full items-center justify-center bg-white/12 text-white text-xs font-bold">
							{initial(user)}
						</span>
					{/if}
				</div>
				<div class="min-w-0 flex-1">
					<p class="text-xs font-medium text-white/80 truncate group-hover:text-white transition-colors">{user.name}</p>
					<p class="text-[11px] text-white/35 truncate">
						{user.username ? `@${user.username}` : user.email}
					</p>
				</div>
				<button
					type="button"
					onclick={(e) => { e.preventDefault(); e.stopPropagation(); close(); signOut.confirm = true; }}
					class="p-1.5 rounded-md text-white/25 hover:text-red-400 hover:bg-red-500/8 transition-colors"
					aria-label="Sign out"
				>
					<SignOutIcon size={15} weight="regular" />
				</button>
			</a>
		</div>
	{:else}
		<div class="p-3 border-t border-white/6 shrink-0">
			<a href="/login"
				class="flex items-center justify-center gap-2 w-full px-3 py-2.5 rounded-lg
				       border border-white/10 text-sm text-white/55 hover:text-white hover:bg-white/5 transition-colors">
				Sign in
			</a>
		</div>
	{/if}
</aside>
