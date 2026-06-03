<script lang="ts">
	import { onDestroy } from 'svelte';

	let {
		height = 20,
		class: className = ''
	}: {
		height?: number;
		class?: string;
	} = $props();

	let showEn = $state(true);

	const timer = setInterval(() => { showEn = !showEn; }, 4000);
	onDestroy(() => clearInterval(timer));
</script>

<div
	class="relative inline-block {className}"
	style="font-size: {height}px; line-height: 1; white-space: nowrap;"
	role="img"
	aria-label={showEn ? 'namizo.' : 'ナミゾ'}
>
	<span
		class="font-bold"
		style="letter-spacing: -0.03em;
		       transition: opacity 0.6s ease-in-out;
		       opacity: {showEn ? 1 : 0};"
		aria-hidden="true"
	>namizo.</span>

	<span
		class="font-bold absolute top-0 left-0"
		style="letter-spacing: 0.06em;
		       transition: opacity 0.6s ease-in-out;
		       opacity: {showEn ? 0 : 1};"
		aria-hidden="true"
	>ナミゾ</span>
</div>
