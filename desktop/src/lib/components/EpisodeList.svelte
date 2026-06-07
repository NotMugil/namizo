<script lang="ts">
    import { onDestroy, onMount } from "svelte";
    import type { Episode } from "$lib/types/anime";
    import { ArrowLeftIcon, ArrowRightIcon } from "phosphor-svelte";

    export let episodes: Episode[];
    export let cover_image: string;
    export let anime_id: number;
    export let totalEpisodes: number | null = null;
    export let canLoadMore: boolean = false;
    export let loadingMore: boolean = false;
    export let onLoadMore: ((requiredCount: number) => void) | null = null;
    export let watchProgress: number = 0;

    let episodePage = 1;
    let perPage = 10;
    let lastAnimeId = anime_id;
    let lastRequestedRequiredCount = 0;
    let isReady = false;

    function getColumns(width: number): number {
        return width < 760 ? 2 : 5;
    }

    function syncPerPage(width: number) {
        const columns = getColumns(width);
        // Mobile: 2 cols × 5 rows = 10; Desktop: 5 cols × 2 rows = 10
        const rows = columns < 3 ? 5 : 2;
        perPage = columns * rows;
    }

    function handleResize() {
        syncPerPage(window.innerWidth);
    }

    onMount(() => {
        syncPerPage(window.innerWidth);
        window.addEventListener("resize", handleResize, { passive: true });
        isReady = true;
    });

    onDestroy(() => {
        window.removeEventListener("resize", handleResize);
    });

    $: hasKnownTotalEpisodes =
        Number.isFinite(totalEpisodes ?? null) && Number(totalEpisodes) > 0;
    $: knownTotalEpisodeCount = hasKnownTotalEpisodes
        ? Number(totalEpisodes)
        : null;
    $: loadedEpisodeCount = episodes.length;
    // Keep page denominator based on known total when available.
    $: effectiveTotalEpisodes = hasKnownTotalEpisodes
        ? (knownTotalEpisodeCount as number)
        : loadedEpisodeCount;
    // For unknown totals, keep one virtual page ahead to allow progressive loading.
    $: virtualTotalEpisodes = hasKnownTotalEpisodes
        ? effectiveTotalEpisodes
        : canLoadMore
            ? loadedEpisodeCount + perPage
            : loadedEpisodeCount;

    $: totalPages = Math.max(1, Math.ceil(Math.max(1, virtualTotalEpisodes) / perPage));
    $: displayTotalPages = Math.max(
        1,
        Math.ceil(Math.max(1, effectiveTotalEpisodes) / perPage),
    );

    $: if (anime_id !== lastAnimeId) {
        episodePage = 1;
        lastAnimeId = anime_id;
        lastRequestedRequiredCount = 0;
    }

    $: if (isReady) {
        episodePage = Math.min(Math.max(episodePage, 1), totalPages);
    }

    $: pageStart = (episodePage - 1) * perPage;
    $: pageEndExclusive = Math.min(pageStart + perPage, virtualTotalEpisodes);
    $: pageSize = Math.max(0, pageEndExclusive - pageStart);
    $: pagedEntries = Array.from({ length: pageSize }, (_, offset) => {
        const index = pageStart + offset;
        const episode = episodes[index];
        return {
            episode,
            fallbackNumber: index + 1,
        };
    });

    $: prefetchBuffer = canLoadMore ? perPage : 0;
    $: requiredCountForPage = hasKnownTotalEpisodes
        ? Math.min(pageEndExclusive + prefetchBuffer, effectiveTotalEpisodes)
        : pageEndExclusive + prefetchBuffer;

    $: if (episodes.length >= lastRequestedRequiredCount) {
        lastRequestedRequiredCount = 0;
    }

    $: if (
        requiredCountForPage > episodes.length &&
        canLoadMore &&
        !loadingMore &&
        requiredCountForPage !== lastRequestedRequiredCount
    ) {
        lastRequestedRequiredCount = requiredCountForPage;
        if (onLoadMore) {
            onLoadMore(requiredCountForPage);
        }
    }

    function onPrevPage() {
        if (episodePage > 1) {
            episodePage -= 1;
        }
    }

    function onNextPage() {
        if (episodePage < totalPages) {
            episodePage += 1;
            return;
        }
        if (canLoadMore && !loadingMore) {
            const fallbackRequiredCount = episodes.length + perPage;
            lastRequestedRequiredCount = fallbackRequiredCount;
            if (onLoadMore) {
                onLoadMore(fallbackRequiredCount);
            }
        }
    }
</script>

{#if episodes.length}
    <section class="grid gap-3 min-w-0">
        <div class="flex items-center justify-between gap-2">
            <h2 class="section-title">Episodes</h2>
            <div class="flex items-center gap-2">
                <span class="text-[12px] text-white/40">
                    Page {episodePage} / {displayTotalPages}
                </span>
                <button
                    class="chevron-btn"
                    disabled={episodePage <= 1}
                    onclick={onPrevPage}
                >
                    <ArrowLeftIcon size={14} weight="bold" />
                </button>
                <button
                    class="chevron-btn"
                    disabled={(episodePage >= totalPages && !canLoadMore) || loadingMore}
                    onclick={onNextPage}
                >
                    <ArrowRightIcon size={14} weight="bold" />
                </button>
            </div>
        </div>

        <div class="grid grid-cols-5 gap-3 max-[760px]:grid-cols-2">
            {#each pagedEntries as entry (entry.fallbackNumber)}
                {#if entry.episode}
                    {@const watched = watchProgress > 0 && entry.episode.number <= watchProgress}
                    <a
                        href="/watch/{anime_id}?ep={entry.episode.number}"
                        class="grid gap-1.5 rounded-xl p-1.5
                               no-underline text-inherit transition-colors min-w-0
                               hover:bg-white/7 hover:border-white/12
                               {watched ? 'opacity-50 hover:opacity-100' : ''}"
                    >
                        <div
                            class="relative w-full aspect-video rounded-lg overflow-hidden border border-white/8 bg-black/20"
                        >
                            <img
                                src={entry.episode.thumbnail ?? cover_image}
                                alt={entry.episode.title ??
                                    `Episode ${entry.episode.number}`}
                                class="w-full h-full object-cover"
                                loading="lazy"
                            />
                            {#if watched}
                                <div class="absolute inset-0 bg-black/30 pointer-events-none"></div>
                                <div class="absolute bottom-1.5 right-1.5 flex items-center justify-center
                                            h-5 w-5 rounded-full bg-black/60 border border-white/20">
                                    <svg width="10" height="10" viewBox="0 0 12 12" fill="none">
                                        <path d="M2 6l3 3 5-5" stroke="white" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                                    </svg>
                                </div>
                            {/if}
                        </div>
                        <div class="grid gap-0.5 px-0.5 pb-1">
                            <p
                                class="text-[11px] uppercase tracking-wide text-white/40 m-0"
                            >
                                EP {entry.episode.number}
                            </p>
                            <h3
                                class="text-[13px] font-medium m-0 line-clamp-1 leading-snug"
                            >
                                {entry.episode.title ??
                                    `Episode ${entry.episode.number}`}
                            </h3>
                        </div>
                    </a>
                {:else}
                    <div
                        class="grid gap-1.5 rounded-xl p-1.5 min-w-0 opacity-80"
                    >
                        <div
                            class="w-full aspect-video rounded-lg overflow-hidden border border-white/8 bg-white/8 animate-pulse"
                        ></div>
                        <div class="grid gap-1 px-0.5 pb-1">
                            <p
                                class="text-[11px] uppercase tracking-wide text-white/40 m-0"
                            >
                                EP {entry.fallbackNumber}
                            </p>
                            <div
                                class="h-3.5 w-[85%] rounded bg-white/10 animate-pulse"
                            ></div>
                        </div>
                    </div>
                {/if}
            {/each}
        </div>

        {#if loadingMore}
            <p class="font-mono text-[12px] text-white/45">Loading more episodes...</p>
        {/if}
    </section>
{/if}