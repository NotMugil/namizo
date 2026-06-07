<script lang="ts">
    import type { AnimeDetails } from '$lib/types/anime';
    import ProviderPill from './ProviderPill.svelte';

    export let anime: AnimeDetails | null = null;
    export let episodeNumber: number = 1;
    export let episodeTitle: string = '';
    export let description: string = '';
    export let providerOptions: { label: string; value: string }[] = [];
    export let provider: string = '';
    export let onProviderChange: ((v: string) => void) | undefined = undefined;

    let shareTooltip = false;

    async function handleShare() {
        if (navigator.share) {
            try { await navigator.share({ title: anime?.title ?? '', url: window.location.href }); } catch {}
        } else {
            await navigator.clipboard.writeText(window.location.href).catch(() => {});
            shareTooltip = true;
            setTimeout(() => (shareTooltip = false), 1800);
        }
    }
</script>

<div class="mt-4 space-y-4">
    <!-- Title block -->
    <div>
        <div class="flex items-center gap-2 mb-1">
            <span class="text-[10px] uppercase tracking-widest text-white/35 font-medium">Episode {episodeNumber}</span>
        </div>
        <h1 class="text-lg font-bold text-white leading-tight">
            {episodeTitle || `Episode ${episodeNumber}`}
        </h1>
        {#if anime}
            <p class="text-sm text-white/50 mt-1">{anime.title}</p>
            <div class="flex items-center gap-3 mt-2 flex-wrap text-[12px] text-white/35">
                {#if anime.season && anime.season_year}
                    <span>{anime.season} {anime.season_year}</span>
                {/if}
                {#if anime.format}
                    <span>{anime.format}</span>
                {/if}
                {#if anime.average_score}
                    <span>★ {(anime.average_score / 10).toFixed(1)}</span>
                {/if}
            </div>
        {/if}
    </div>

    <!-- Action buttons -->
    <div class="flex flex-wrap items-center gap-2">
        <!-- Share -->
        <div class="relative">
            <button
                class="flex items-center gap-1.5 h-8 px-3.5 rounded-full border text-[12px] font-medium
                       bg-white/5 border-white/10 text-white/55 hover:bg-white/10 hover:border-white/20 hover:text-white/80
                       transition-all duration-150"
                onclick={handleShare}
            >
                <svg width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/>
                    <line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/>
                </svg>
                Share
            </button>
            {#if shareTooltip}
                <div class="absolute -top-8 left-1/2 -translate-x-1/2 bg-[#1a1a1a] border border-white/12 rounded-lg px-2 py-1 text-[10px] text-white whitespace-nowrap pointer-events-none z-10">
                    Link copied!
                </div>
            {/if}
        </div>

        <!-- Provider picker — same pill styling as Share, opens upward -->
        {#if providerOptions.length > 0}
            <ProviderPill
                options={providerOptions}
                value={provider}
                onChange={onProviderChange}
            />
        {/if}
    </div>

    <!-- Description -->
    {#if description || anime?.description}
        {@const raw = description || anime?.description || ''}
        {@const text = raw.replace(/<[^>]*>/g, '')}
        <div class="rounded-xl border border-white/6 bg-white/3 p-4">
            <p class="text-[13px] text-white/55 leading-relaxed line-clamp-4">{text}</p>
        </div>
    {/if}

    <!-- Genres -->
    {#if anime?.genres?.length}
        <div class="flex flex-wrap gap-1.5">
            {#each anime.genres as genre}
                <span class="chip">{genre}</span>
            {/each}
        </div>
    {/if}
</div>
