<script lang="ts">
	import type { LayoutData } from './$types';
	import Topbar from '$lib/components/layout/Topbar.svelte';
	import Sidebar from '$lib/components/layout/Sidebar.svelte';
	import ConfirmDialog from '$lib/components/shared/ConfirmDialog.svelte';
	import { sidebar, signOut } from '$lib/state.svelte';
	import { enhance } from '$app/forms';
	import { Toaster } from 'svelte-sonner';

	let { children, data }: { children: import('svelte').Snippet; data: LayoutData } = $props();

	let signOutFormEl: HTMLFormElement | undefined = $state();
</script>

<div class="flex flex-col min-h-screen bg-black text-white">
	<Topbar onMenuClick={() => (sidebar.open = !sidebar.open)} user={data.user} />
	<main class="flex-1">
		{@render children()}
	</main>
</div>

<!-- Sidebar backdrop -->
<button
	type="button"
	aria-label="Close sidebar"
	class="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm transition-opacity duration-300
	       {sidebar.open ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}"
	onclick={() => (sidebar.open = false)}
></button>

<!-- Sidebar drawer -->
<div
	class="fixed top-0 left-0 h-full z-50 shadow-2xl
	       transition-transform duration-300
	       {sidebar.open ? 'translate-x-0' : '-translate-x-full'}"
>
	<Sidebar user={data.user} />
</div>

<!-- Sign-out form + confirmation dialog — rendered at root so the dialog covers the full screen -->
<form bind:this={signOutFormEl} method="post" action="/sign-out" use:enhance class="hidden"></form>

<ConfirmDialog
	bind:open={signOut.confirm}
	title="Sign out of Namizo?"
	description="You'll need your credentials to sign back in."
	confirmLabel="Sign out"
	cancelLabel="Stay"
	destructive={true}
	onConfirm={() => signOutFormEl?.requestSubmit()}
/>

<Toaster theme="dark" richColors position="bottom-right" />
