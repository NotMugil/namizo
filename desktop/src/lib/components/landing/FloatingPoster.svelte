<script lang="ts">
	let {
		image,
		title = '',
		x,
		y,
		rotation,
		layer,
		scale,
		driftVariant,
		driftDelay,
		parallaxX = 0,
		parallaxY = 0,
		reducedMotion = false
	}: {
		image: string;
		title?: string;
		x: number;
		y: number;
		rotation: number;
		layer: 1 | 2 | 3;
		scale: number;
		driftVariant: number;
		driftDelay: number;
		parallaxX?: number;
		parallaxY?: number;
		reducedMotion?: boolean;
	} = $props();

	let cardEl: HTMLDivElement | undefined = $state();
	let isHovered = $state(false);
	let tiltX = $state(0);
	let tiltY = $state(0);

	const OPACITY = { 1: 0.26, 2: 0.46, 3: 0.68 };
	const BLUR = { 1: 'blur(1.5px)', 2: 'blur(0px)', 3: 'blur(0px)' };
	const DRIFT_DURATION = [88, 76, 95, 103, 82, 68, 91, 74];

	const opacity = $derived(OPACITY[layer]);
	const blurFilter = $derived(BLUR[layer]);
	const duration = $derived(DRIFT_DURATION[driftVariant % DRIFT_DURATION.length]);

	const hoverScale = $derived(isHovered ? scale * 1.07 : scale);
	const brightness = $derived(isHovered ? 1.35 : 1.0);
	const hoverShadow = $derived(
		isHovered
			? '0 28px 56px rgba(0,0,0,0.75), 0 0 0 1px rgba(255,255,255,0.12)'
			: `0 ${4 + layer * 4}px ${12 + layer * 8}px rgba(0,0,0,0.5)`
	);

	const driftAnimation = $derived(
		reducedMotion
			? 'none'
			: `poster-drift-${driftVariant} ${duration}s ease-in-out ${driftDelay}s infinite`
	);

	function handleMouseEnter() { isHovered = true; }
	function handleMouseLeave() { isHovered = false; tiltX = 0; tiltY = 0; }
	function handleMouseMove(e: MouseEvent) {
		if (!cardEl || reducedMotion) return;
		const rect = cardEl.getBoundingClientRect();
		const dx = (e.clientX - (rect.left + rect.width / 2)) / (rect.width / 2);
		const dy = (e.clientY - (rect.top + rect.height / 2)) / (rect.height / 2);
		tiltX = Math.max(-1, Math.min(1, dy)) * -10;
		tiltY = Math.max(-1, Math.min(1, dx)) * 10;
	}
</script>

<div
	class="absolute"
	style:left="{x}%"
	style:top="{y}%"
	style:transform="translate(-50%, -50%) translate({parallaxX}px, {parallaxY}px)"
	style:z-index={isHovered ? 8 : layer}
	style:will-change="transform"
	style:pointer-events="auto"
>
	<div style:animation={driftAnimation}>
		<div style:position="relative" style:transform="rotateZ({rotation}deg)" style:perspective="700px">
			<div
				bind:this={cardEl}
				class="relative overflow-hidden rounded-xl cursor-pointer select-none"
				style:width="130px"
				style:aspect-ratio="2/3"
				style:border="1px solid rgba(255,255,255,0.08)"
				style:opacity
				style:filter="{blurFilter} brightness({brightness})"
				style:box-shadow={hoverShadow}
				style:transform="scale({hoverScale}) rotateX({tiltX}deg) rotateY({tiltY}deg)"
				style:transition="transform 380ms cubic-bezier(0.23, 1, 0.32, 1), opacity 400ms ease, filter 300ms ease, box-shadow 380ms ease"
				style:will-change="transform"
				style:transform-style="preserve-3d"
				onmouseenter={handleMouseEnter}
				onmouseleave={handleMouseLeave}
				onmousemove={handleMouseMove}
				role="img"
				aria-label={title}
			>
				<img src={image} alt={title} class="h-full w-full object-cover" loading="lazy" draggable="false" />
				<div class="absolute inset-0 pointer-events-none"
					style:background="linear-gradient(to bottom, transparent 60%, rgba(0,0,0,0.3) 100%)"></div>
				{#if isHovered}
					<div class="absolute inset-0 pointer-events-none"
						style:background="linear-gradient(135deg, rgba(255,255,255,0.06) 0%, transparent 60%)"></div>
				{/if}
			</div>

			<div
				style:position="absolute"
				style:top="calc(100% + 9px)"
				style:left="50%"
				style:transform="translateX(-50%) translateY({isHovered ? '0px' : '5px'})"
				style:opacity={isHovered ? 1 : 0}
				style:transition="opacity 240ms ease, transform 240ms ease"
				style:pointer-events="none"
			>
				<span
					class="block rounded-full font-medium tracking-wide truncate"
					style:padding="3px 10px"
					style:font-size="10px"
					style:max-width="150px"
					style:background="rgba(255,255,255,0.08)"
					style:border="1px solid rgba(255,255,255,0.13)"
					style:backdrop-filter="blur(12px)"
					style:-webkit-backdrop-filter="blur(12px)"
					style:color="rgba(238,238,245,0.65)"
					style:letter-spacing="0.02em"
				>{title}</span>
			</div>
		</div>
	</div>
</div>

<style>
	@keyframes poster-drift-0 { 0%,100%{transform:translate(0,0)} 25%{transform:translate(16px,-22px)} 55%{transform:translate(-10px,18px)} 78%{transform:translate(12px,8px)} }
	@keyframes poster-drift-1 { 0%,100%{transform:translate(0,0)} 33%{transform:translate(-18px,14px)} 66%{transform:translate(22px,-16px)} }
	@keyframes poster-drift-2 { 0%,100%{transform:translate(0,0)} 20%{transform:translate(10px,20px)} 55%{transform:translate(-20px,-14px)} 80%{transform:translate(14px,8px)} }
	@keyframes poster-drift-3 { 0%,100%{transform:translate(0,0)} 40%{transform:translate(20px,12px)} 72%{transform:translate(-10px,-20px)} }
	@keyframes poster-drift-4 { 0%,100%{transform:translate(0,0)} 30%{transform:translate(-16px,-20px)} 60%{transform:translate(18px,14px)} 85%{transform:translate(-8px,22px)} }
	@keyframes poster-drift-5 { 0%,100%{transform:translate(0,0)} 45%{transform:translate(22px,-10px)} 75%{transform:translate(-14px,18px)} }
	@keyframes poster-drift-6 { 0%,100%{transform:translate(0,0)} 25%{transform:translate(-20px,14px)} 52%{transform:translate(10px,-20px)} 78%{transform:translate(18px,20px)} }
	@keyframes poster-drift-7 { 0%,100%{transform:translate(0,0)} 38%{transform:translate(14px,24px)} 68%{transform:translate(-20px,-12px)} }
</style>
