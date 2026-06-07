<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { LayoutData } from './$types';
	import FloatingScene from '$lib/components/landing/FloatingScene.svelte';

	let { children, data }: { children: Snippet; data: LayoutData } = $props();
</script>

<div class="relative min-h-screen w-full overflow-hidden bg-[#080808]">
	<FloatingScene posters={data.posters} />

	<!-- Radial vignette for text legibility -->
	<div
		class="fixed inset-0 pointer-events-none"
		style:z-index="4"
		style:background="radial-gradient(ellipse 55% 65% at 50% 50%, rgba(8,8,8,0.92) 0%, rgba(8,8,8,0.70) 40%, rgba(8,8,8,0.20) 70%, transparent 100%)"
	></div>

	<!-- Centered form content -->
	<div class="relative flex min-h-screen w-full items-center justify-center px-4 py-10" style:z-index="10">
		{@render children()}
	</div>
</div>
