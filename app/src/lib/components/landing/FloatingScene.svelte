<script lang="ts">
	import { onMount } from 'svelte';
	import FloatingPoster from './FloatingPoster.svelte';

	let { posters = [] }: { posters: Array<{ id: number; title: string; image: string }> } = $props();

	const POSTER_DEFS = [
		{ x: 3, y: 7, rotation: -8, layer: 1, scale: 0.75 },
		{ x: 83, y: 6, rotation: 6, layer: 1, scale: 0.78 },
		{ x: 4, y: 62, rotation: 4, layer: 1, scale: 0.72 },
		{ x: 88, y: 58, rotation: -5, layer: 1, scale: 0.76 },
		{ x: 34, y: 93, rotation: 3, layer: 1, scale: 0.70 },
		{ x: 61, y: 94, rotation: -7, layer: 1, scale: 0.73 },
		{ x: 91, y: 32, rotation: 9, layer: 1, scale: 0.77 },
		{ x: 1, y: 40, rotation: -4, layer: 1, scale: 0.74 },
		{ x: 16, y: 11, rotation: 5, layer: 2, scale: 0.88 },
		{ x: 76, y: 13, rotation: -7, layer: 2, scale: 0.90 },
		{ x: 18, y: 82, rotation: -3, layer: 2, scale: 0.86 },
		{ x: 80, y: 80, rotation: 6, layer: 2, scale: 0.92 },
		{ x: 44, y: 4, rotation: -5, layer: 2, scale: 0.85 },
		{ x: 50, y: 93, rotation: 4, layer: 2, scale: 0.87 },
		{ x: 9, y: 48, rotation: 8, layer: 2, scale: 0.84 },
		{ x: 89, y: 22, rotation: -9, layer: 2, scale: 0.89 },
		{ x: 24, y: 2, rotation: -6, layer: 3, scale: 1.00 },
		{ x: 70, y: 3, rotation: 8, layer: 3, scale: 1.02 },
		{ x: 4, y: 24, rotation: 5, layer: 3, scale: 0.96 },
		{ x: 93, y: 50, rotation: -4, layer: 3, scale: 0.98 },
		{ x: 25, y: 90, rotation: 7, layer: 3, scale: 0.95 },
		{ x: 74, y: 88, rotation: -5, layer: 3, scale: 1.00 },
		{ x: 5, y: 80, rotation: 3, layer: 3, scale: 0.97 },
		{ x: 88, y: 74, rotation: -8, layer: 3, scale: 0.99 }
	] as const;

	const activeDefs = $derived(
		POSTER_DEFS.slice(0, Math.min(POSTER_DEFS.length, posters.length)).map((def, i) => ({
			...def,
			image: posters[i].image,
			title: posters[i].title,
			driftVariant: i % 8,
			driftDelay: -(i * 11.7)
		}))
	);

	let mouseNormX = $state(0.5);
	let mouseNormY = $state(0.5);
	let targetX = 0.5;
	let targetY = 0.5;
	let rafId = 0;

	function lerp(a: number, b: number, t: number) { return a + (b - a) * t; }

	function tick() {
		mouseNormX = lerp(mouseNormX, targetX, 0.04);
		mouseNormY = lerp(mouseNormY, targetY, 0.04);
		rafId = requestAnimationFrame(tick);
	}

	function handleMouseMove(e: MouseEvent) {
		targetX = e.clientX / window.innerWidth;
		targetY = e.clientY / window.innerHeight;
	}

	let windowWidth = $state(1440);

	const visibleDefs = $derived(
		activeDefs.filter((d) => {
			if (windowWidth < 640) return d.y < 20 || d.y > 80;
			if (windowWidth < 1024) return d.layer !== 1;
			return true;
		})
	);

	const maskImage = $derived(
		windowWidth < 640
			? 'linear-gradient(to bottom, black 0%, transparent 28%, transparent 72%, black 100%)'
			: 'radial-gradient(ellipse 92% 92% at 50% 50%, black 55%, transparent 100%)'
	);

	const PARALLAX_STRENGTH = { 1: 18, 2: 36, 3: 60 } as const;

	const parallax = $derived({
		1: { x: -(mouseNormX - 0.5) * 2 * PARALLAX_STRENGTH[1], y: -(mouseNormY - 0.5) * 2 * PARALLAX_STRENGTH[1] },
		2: { x: -(mouseNormX - 0.5) * 2 * PARALLAX_STRENGTH[2], y: -(mouseNormY - 0.5) * 2 * PARALLAX_STRENGTH[2] },
		3: { x: -(mouseNormX - 0.5) * 2 * PARALLAX_STRENGTH[3], y: -(mouseNormY - 0.5) * 2 * PARALLAX_STRENGTH[3] }
	});

	let reducedMotion = $state(false);

	onMount(() => {
		windowWidth = window.innerWidth;

		const motionMq = window.matchMedia('(prefers-reduced-motion: reduce)');
		reducedMotion = motionMq.matches;
		const onMotionChange = (e: MediaQueryListEvent) => {
			reducedMotion = e.matches;
			if (e.matches) cancelAnimationFrame(rafId);
			else if (!document.hidden) rafId = requestAnimationFrame(tick);
		};
		motionMq.addEventListener('change', onMotionChange);

		const onVisibility = () => {
			if (document.hidden) cancelAnimationFrame(rafId);
			else if (!reducedMotion) rafId = requestAnimationFrame(tick);
		};
		document.addEventListener('visibilitychange', onVisibility);
		window.addEventListener('mousemove', handleMouseMove, { passive: true });
		const onResize = () => { windowWidth = window.innerWidth; };
		window.addEventListener('resize', onResize, { passive: true });

		if (!reducedMotion) rafId = requestAnimationFrame(tick);

		return () => {
			cancelAnimationFrame(rafId);
			motionMq.removeEventListener('change', onMotionChange);
			document.removeEventListener('visibilitychange', onVisibility);
			window.removeEventListener('mousemove', handleMouseMove);
			window.removeEventListener('resize', onResize);
		};
	});
</script>

<div
	class="fixed inset-0 overflow-hidden"
	aria-hidden="true"
	style:z-index="0"
	style:pointer-events="none"
	style:mask-image={maskImage}
	style:-webkit-mask-image={maskImage}
>
	{#each visibleDefs as def (`${def.x}-${def.y}-${def.layer}`)}
		<FloatingPoster
			image={def.image}
			title={def.title}
			x={def.x}
			y={def.y}
			rotation={def.rotation}
			layer={def.layer}
			scale={def.scale}
			driftVariant={def.driftVariant}
			driftDelay={def.driftDelay}
			parallaxX={parallax[def.layer].x}
			parallaxY={parallax[def.layer].y}
			{reducedMotion}
		/>
	{/each}
</div>
