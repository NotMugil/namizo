<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { breadcrumb } from '$lib/state.svelte';
	import type { PageData } from './$types';
	import type { DayGroup, ScheduleEntry } from './+page.server';
	import ScheduleCard from '$lib/components/schedule/ScheduleCard.svelte';

	let { data }: { data: PageData } = $props();

	const days: DayGroup[] = $derived(data.days);
	const userIds = $derived(new Set(data.userAnilistIds));
	const scheduleError = $derived(data.scheduleError ?? false);

	// Auto-select today (index 7 in the 21-day array)
	let selectedDay = $state(7);

	// Live clock
	let now = $state(new Date());
	let clockInterval: ReturnType<typeof setInterval>;

	// Tab bar scroll ref — auto-scroll today into view on mount
	let tabBar: HTMLDivElement | undefined = $state();

	onMount(() => {
		breadcrumb.items = [{ label: 'Home', href: '/' }, { label: 'Schedule' }];
		clockInterval = setInterval(() => { now = new Date(); }, 1000);
		// Scroll today's tab into view
		setTimeout(() => {
			tabBar?.children[7]?.scrollIntoView({ inline: 'center', behavior: 'smooth', block: 'nearest' });
		}, 100);
	});
	onDestroy(() => { breadcrumb.items = []; clearInterval(clockInterval); });

	function formatClock(d: Date): string {
		return d.toLocaleString(undefined, {
			timeZoneName: 'short',
			month: 'numeric', day: 'numeric', year: 'numeric',
			hour: 'numeric', minute: '2-digit', second: '2-digit'
		});
	}

	function formatTimeLabel(unix: number): string {
		return new Date(unix * 1000).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', hour12: false });
	}

	function formatTimeDisplay(unix: number): string {
		return new Date(unix * 1000).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
	}

	// Group entries within a day by their HH:MM slot (local time)
	interface TimeSlot {
		label: string;      // "15:00"
		firstAiringAt: number;
		entries: ScheduleEntry[];
	}

	function groupByTime(entries: ScheduleEntry[]): TimeSlot[] {
		const map = new Map<string, TimeSlot>();
		for (const e of entries) {
			const label = formatTimeLabel(e.airingAt);
			if (!map.has(label)) map.set(label, { label, firstAiringAt: e.airingAt, entries: [] });
			map.get(label)!.entries.push(e);
		}
		return [...map.values()].sort((a, b) => a.firstAiringAt - b.firstAiringAt);
	}

	const currentDaySlots = $derived(groupByTime(days[selectedDay]?.entries ?? []));
</script>

<svelte:head><title>Schedule — Namizo</title></svelte:head>

<div class="flex flex-col min-h-screen pt-14">

	<!-- Header -->
	<div class="flex items-baseline justify-between px-6 pt-6 pb-4 sm:px-8 lg:px-10">
		<h1 class="text-[1.4rem] font-bold text-white">Estimated Schedule</h1>
		<p class="text-[0.75rem] text-white/40 tabular-nums shrink-0">{formatClock(now)}</p>
	</div>

	<!-- Day tab bar -->
	<div bind:this={tabBar}
		class="flex overflow-x-auto gap-2 px-4 pb-3 sm:px-8 lg:px-10 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden shrink-0">
		{#each days as day, i}
			<button type="button"
				onclick={() => (selectedDay = i)}
				class="shrink-0 flex flex-col items-center justify-center rounded-xl px-4 py-2.5 min-w-18 transition-all
				       {day.isToday && selectedDay === i
				           ? 'bg-white text-black font-bold'
				           : day.isToday
				               ? 'border border-white/40 text-white font-semibold hover:bg-white/5'
				               : selectedDay === i
				                   ? 'bg-white/12 text-white font-semibold'
				                   : day.isPast
				                       ? 'text-white/25 hover:bg-white/5 hover:text-white/50'
				                       : 'text-white/55 hover:bg-white/5 hover:text-white/80'}">
				<span class="text-[0.85rem] font-bold leading-tight">{day.shortDay}</span>
				<span class="text-[0.7rem] leading-tight mt-0.5
				             {day.isToday && selectedDay === i ? 'text-black/60' : 'opacity-70'}">{day.monthDay}</span>
			</button>
		{/each}
	</div>

	<!-- Divider -->
	<div class="border-b border-white/6 mx-4 sm:mx-8 lg:mx-10"></div>

	<!-- Timeline content -->
	<div class="flex-1 overflow-y-auto px-4 sm:px-8 lg:px-10 py-6">
		{#if scheduleError}
			<div class="flex items-center justify-center py-20">
				<p class="text-white/30 text-sm">Could not load schedule — AniList may be unavailable. Try refreshing.</p>
			</div>
		{:else if currentDaySlots.length === 0}
			<div class="flex items-center justify-center py-20">
				<p class="text-white/30 text-sm">No episodes airing on {days[selectedDay]?.dayName ?? 'this day'}.</p>
			</div>
		{:else}
			<div class="flex flex-col gap-4">
				{#each currentDaySlots as slot (slot.label)}
					<div class="flex gap-4 items-start">
						<!-- Time label -->
						<div class="w-14 shrink-0 pt-3 text-right">
							<span class="text-[0.82rem] font-medium text-white/40 tabular-nums">{slot.label}</span>
						</div>

						<!-- Vertical rule -->
						<div class="w-px self-stretch bg-white/8 shrink-0 mt-2"></div>

						<!-- Cards at this time slot (wrap into rows) -->
						<div class="flex flex-wrap gap-2 flex-1 min-w-0">
							{#each slot.entries as entry (entry.id)}
								<div class="w-full sm:w-[calc(50%-4px)] lg:w-[calc(33.333%-6px)] xl:w-72">
									<ScheduleCard {entry} isTracked={userIds.has(entry.media.id)} />
								</div>
							{/each}
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>
