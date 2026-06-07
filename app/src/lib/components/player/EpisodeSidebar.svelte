<script lang="ts">
    import { browser } from '$app/environment';
    import { onMount } from 'svelte';

    export let episodes: { number: number; title: string | null; thumbnail: string | null }[] = [];
    export let episodeNumbers: number[] = [];
    export let fillerNumbers: Set<number> = new Set();
    export let recapNumbers: Set<number> = new Set();
    export let selectedNumber: number = 1;
    export let loading: boolean = false;
    export let animeTitle: string = '';
    export let episodeTitle: string = '';
    export let onSelect: ((n: number) => void) | undefined = undefined;

    type DisplayMode = 'card' | 'list';
    const LS_KEY = 'namizo:ep-view';
    const RANGE_SIZE = 100;

    let displayMode: DisplayMode = 'card';
    let search = '';
    let rangeStart = 0;
    let reversed = false;

    onMount(() => {
        try {
            const saved = localStorage.getItem(LS_KEY) as DisplayMode | null;
            if (saved === 'card' || saved === 'list') displayMode = saved;
        } catch {}
        // Set initial range to contain the currently selected episode
        if (selectedNumber > 0) {
            rangeStart = Math.floor((selectedNumber - 1) / RANGE_SIZE) * RANGE_SIZE;
        }
    });

    $: if (browser) {
        try { localStorage.setItem(LS_KEY, displayMode); } catch {}
    }

    $: sorted = (() => {
        const base = episodes.length > 0
            ? [...episodes].sort((a, b) => a.number - b.number)
            : [...episodeNumbers].sort((a, b) => a - b).map(n => ({
                number: n, title: null as string | null, thumbnail: null as string | null
            }));
        return reversed ? [...base].reverse() : base;
    })();

    $: maxEp = sorted.length
        ? Math.max(...sorted.map(e => e.number))
        : 0;

    $: rangeOptions = (() => {
        const opts: { label: string; start: number }[] = [];
        for (let s = 0; s < Math.max(maxEp, 1); s += RANGE_SIZE)
            opts.push({ label: `${s + 1}–${s + RANGE_SIZE}`, start: s });
        return opts;
    })();

    // Initial range is set once in onMount (see below). Reactivity intentionally
    // excluded here to prevent the block from fighting user-driven range changes.

    $: inRange = reversed
        ? sorted.filter(e => e.number > rangeStart && e.number <= rangeStart + RANGE_SIZE)
        : sorted.filter(e => e.number > rangeStart && e.number <= rangeStart + RANGE_SIZE);

    $: filtered = (() => {
        const q = search.trim().toLowerCase();
        if (!q) return inRange;
        return sorted.filter(e =>
            String(e.number).includes(q) ||
            (e.title?.toLowerCase().includes(q) ?? false)
        );
    })();

    // Range picker
    let rangePanelOpen = false;

    function toggleReverse() {
        reversed = !reversed;
    }

    // Jump range to contain episode n, then fire onSelect.
    // Doing this in the click handler (not a reactive block) avoids the
    // reactive block re-reading rangeStart and immediately undoing manual range changes.
    function handleSelect(n: number) {
        const bucket = Math.floor((n - 1) / RANGE_SIZE) * RANGE_SIZE;
        if (bucket !== rangeStart) rangeStart = bucket;
        onSelect?.(n);
    }
</script>

<div class="flex flex-1 min-h-0 flex-col">
    <!-- ── Header ── -->
    <div class="px-3 pt-1 pb-3 shrink-0">
        <div class="flex items-start justify-between gap-2">
            <div class="min-w-0">
                <p class="text-[14.5px] font-bold text-white leading-snug line-clamp-2">
                    {episodeTitle || 'Select Episode'}
                </p>
                {#if animeTitle}
                    <p class="text-[11.5px] text-white/45 mt-0.5 truncate">{animeTitle}</p>
                {/if}
            </div>
            <!-- Range indicator + up/down -->
            {#if rangeOptions.length > 1}
                <div class="shrink-0 flex items-center gap-1 mt-0.5">
                    <button
                        class="text-[10px] text-white/35 hover:text-white/60 transition-colors tabular-nums"
                        onclick={() => (rangePanelOpen = !rangePanelOpen)}
                        title="Change range"
                    >{rangeOptions.find(o => o.start === rangeStart)?.label ?? ''}</button>
                    <svg width="13" height="13" fill="none" stroke="currentColor" stroke-width="2"
                        viewBox="0 0 24 24"
                        class="text-white/30 transition-transform {rangePanelOpen ? 'rotate-180' : ''}"
                        onclick={() => (rangePanelOpen = !rangePanelOpen)}
                    >
                        <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                    </svg>
                </div>
            {/if}
        </div>

        <!-- Range dropdown -->
        {#if rangePanelOpen && rangeOptions.length > 1}
            <div class="mt-2 rounded-xl border border-white/8 bg-[#111] overflow-hidden">
                {#each rangeOptions as opt (opt.start)}
                    <button
                        class="w-full text-left px-3 py-2 text-[12px] transition-colors
                               {opt.start === rangeStart
                                 ? 'text-white font-medium bg-white/8'
                                 : 'text-white/50 hover:bg-white/5 hover:text-white/80'}"
                        onclick={() => { rangeStart = opt.start; rangePanelOpen = false; }}
                    >{opt.label}</button>
                {/each}
            </div>
        {/if}
    </div>

    <!-- ── Search + toolbar ── -->
    <div class="flex items-center gap-2 shrink-0 px-3 pb-3">
        <!-- Search input -->
        <div class="relative flex-1 min-w-0">
            <svg width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"
                class="absolute left-3 top-1/2 -translate-y-1/2 text-white/30 pointer-events-none">
                <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
            </svg>
            <input
                class="h-10 w-full rounded-xl border border-white/8 bg-white/5
                       pl-9 pr-3 text-[13px] text-white placeholder:text-white/35
                       focus:border-white/20 focus:outline-none transition-colors"
                placeholder="Search Episode"
                bind:value={search}
            />
        </div>

        <!-- Sort order toggle -->
        <button
            class="h-10 w-10 shrink-0 flex items-center justify-center rounded-xl transition-colors
                   {reversed ? 'bg-white/15 text-white' : 'bg-white/8 text-white/55 hover:bg-white/12 hover:text-white/80'}"
            onclick={toggleReverse}
            title={reversed ? 'Newest first' : 'Oldest first'}
            aria-label="Toggle sort order"
        >
            <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12"/>
            </svg>
        </button>

        <!-- View toggle: card vs list -->
        <button
            class="h-10 w-10 shrink-0 flex items-center justify-center rounded-xl bg-white/8 text-white/55 hover:bg-white/12 hover:text-white/80 transition-colors"
            onclick={() => (displayMode = displayMode === 'card' ? 'list' : 'card')}
            title={displayMode === 'card' ? 'Switch to list view' : 'Switch to card view'}
            aria-label="Toggle view mode"
        >
            {#if displayMode === 'card'}
                <!-- Grid / card icon -->
                <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/>
                    <rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>
                </svg>
            {:else}
                <!-- List icon -->
                <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/>
                    <line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>
                </svg>
            {/if}
        </button>
    </div>

    <!-- ── Episode list ── -->
    <div class="ep-scroll flex-1 min-h-0 overflow-y-auto">

        {#if loading}
            {#if displayMode === 'card'}
                <div class="space-y-1">
                    {#each Array.from({ length: 6 }) as _}
                        <div class="flex gap-3 py-1 px-3">
                            <div class="w-[38%] aspect-video rounded-xl bg-white/6 animate-pulse shrink-0"></div>
                            <div class="flex-1 flex flex-col justify-center gap-2 py-1">
                                <div class="h-3 w-3/4 rounded bg-white/6 animate-pulse"></div>
                                <div class="h-2.5 w-1/2 rounded bg-white/5 animate-pulse"></div>
                            </div>
                        </div>
                    {/each}
                </div>
            {:else}
                <div>
                    {#each Array.from({ length: 8 }) as _}
                        <div class="flex items-center gap-4 py-3.5 px-3 border-b border-white/5">
                            <div class="h-3 w-8 rounded bg-white/6 animate-pulse shrink-0"></div>
                            <div class="h-3 flex-1 rounded bg-white/6 animate-pulse"></div>
                        </div>
                    {/each}
                </div>
            {/if}

        {:else if filtered.length === 0}
            <div class="flex items-center justify-center py-16">
                <p class="text-[13px] text-white/30">{search ? 'No episodes match' : 'No episodes in range'}</p>
            </div>

        {:else if displayMode === 'card'}
            <div>
                {#each filtered as item (item.number)}
                    {@const active = item.number === selectedNumber}
                    {@const isFiller = fillerNumbers.has(item.number)}
                    {@const isRecap  = recapNumbers.has(item.number)}
                    <button
                        class="group w-full text-left flex items-start gap-3 py-2 px-3 transition-colors
                               {active ? 'bg-white/8' : 'hover:bg-white/5'}"
                        onclick={() => handleSelect(item.number)}
                    >
                        <!-- Thumbnail with Ep N badge -->
                        <div class="relative shrink-0 w-[34%] aspect-video overflow-hidden rounded-sm bg-white/6">
                            {#if item.thumbnail}
                                <img
                                    src={item.thumbnail}
                                    alt="Ep {item.number}"
                                    class="h-full w-full object-cover transition-opacity duration-150
                                           {active ? 'opacity-100' : 'opacity-75 group-hover:opacity-95'}"
                                    loading="lazy"
                                />
                            {:else}
                                <div class="h-full w-full flex items-center justify-center text-white/15">
                                    <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round"
                                            d="m15.75 10.5 4.72-4.72a.75.75 0 0 1 1.28.53v11.38a.75.75 0 0 1-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 0 0 2.25-2.25v-9A2.25 2.25 0 0 0 13.5 7.5h-9A2.25 2.25 0 0 0 2.25 9.75v9a2.25 2.25 0 0 0 2.25 2.25Z"/>
                                    </svg>
                                </div>
                            {/if}

                            <span class="absolute bottom-1.5 left-1.5 rounded-md bg-black/65 backdrop-blur-sm
                                         px-1.5 py-0.5 text-[10px] font-semibold text-white leading-none">
                                Ep {item.number}
                            </span>

                            {#if active}
                                <div class="absolute inset-0 flex items-center justify-center bg-black/30 rounded-xl">
                                    <div class="h-8 w-8 flex items-center justify-center rounded-full bg-white/20 backdrop-blur-sm">
                                        <svg width="12" height="12" fill="white" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                                    </div>
                                </div>
                            {/if}

                            <!-- Filler / recap tint -->
                            {#if isFiller}
                                <div class="absolute top-1.5 right-1.5 rounded px-1 py-0.5 bg-orange-500/70 text-[9px] font-bold text-white">F</div>
                            {:else if isRecap}
                                <div class="absolute top-1.5 right-1.5 rounded px-1 py-0.5 bg-blue-500/70 text-[9px] font-bold text-white">R</div>
                            {/if}
                        </div>

                        <!-- Info -->
                        <div class="flex-1 min-w-0 pt-0.5">
                            <p class="text-[13.5px] font-semibold leading-snug line-clamp-2 transition-colors
                                      {active ? 'text-white' : 'text-white/80 group-hover:text-white'}">
                                {item.title ?? `Episode ${item.number}`}
                            </p>
                            <p class="mt-1 text-[11.5px] text-white/35">
                                {item.title ? `Episode ${item.number}` : ''}
                            </p>
                        </div>
                    </button>
                {/each}
            </div>

        {:else}
            <!-- ── List view EPisode thumbnails ── -->
            <div>
                {#each filtered as item, idx (item.number)}
                    {@const active = item.number === selectedNumber}
                    <button
                        class="w-full text-left flex items-center gap-4 py-3.5 px-3 transition-colors
                               {idx < filtered.length - 1 ? 'border-b border-white/6' : ''}
                               {active ? 'text-white bg-white/5' : 'text-white/55 hover:text-white/85 hover:bg-white/4'}"
                        onclick={() => handleSelect(item.number)}
                    >
                        <span class="shrink-0 text-[13.5px] {active ? 'font-bold text-white' : 'font-semibold text-white/40'} tabular-nums w-5 text-right">
                            {item.number}.
                        </span>
                        <span class="text-[13.5px] font-medium leading-snug line-clamp-1 flex-1 min-w-0">
                            {item.title ?? `Episode ${item.number}`}
                        </span>
                        {#if active}
                            <svg width="10" height="10" fill="currentColor" viewBox="0 0 24 24" class="shrink-0 text-white/50">
                                <path d="M8 5v14l11-7z"/>
                            </svg>
                        {/if}
                    </button>
                {/each}
            </div>
        {/if}
    </div>
</div>

<style>
    /* Auto-hide scrollbar: invisible at rest, fades in on hover/scroll */
    .ep-scroll {
        scrollbar-width: thin;
        scrollbar-color: transparent transparent;
        transition: scrollbar-color 0.2s;
    }
    .ep-scroll:hover {
        scrollbar-color: rgba(255, 255, 255, 0.1) transparent;
    }
    /* WebKit (Chrome / Edge / Safari) */
    .ep-scroll::-webkit-scrollbar {
        width: 4px;
    }
    .ep-scroll::-webkit-scrollbar-track {
        background: transparent;
    }
    .ep-scroll::-webkit-scrollbar-thumb {
        background: transparent;
        border-radius: 2px;
        transition: background 0.2s;
    }
    .ep-scroll:hover::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.1);
    }
</style>
