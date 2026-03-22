<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import type { Episode } from "$lib/types/anime";
    import { ArrowLeftIcon, ArrowRightIcon } from "phosphor-svelte";
    import { EPISODES_PER_PAGE } from "$lib/constants/ui";

    const dispatch = createEventDispatcher<{
        loadMore: { requiredCount: number };
    }>();

    export let episodes: Episode[];
    export let cover_image: string;
    export let anime_id: number;
    export let totalEpisodes: number | null = null;
    export let canLoadMore: boolean = false;
    export let loadingMore: boolean = false;

    let episodePage = 1;
    let lastAnimeId = anime_id;
    let lastRequestedRequiredCount = 0;

    $: effectiveTotalEpisodes = Math.max(
        episodes.length,
        Number.isFinite(totalEpisodes ?? null) ? (totalEpisodes as number) : 0,
    );
    $: totalPages = Math.max(
        1,
        Math.ceil(effectiveTotalEpisodes / EPISODES_PER_PAGE),
    );

    $: if (anime_id !== lastAnimeId) {
        episodePage = 1;
        lastAnimeId = anime_id;
        lastRequestedRequiredCount = 0;
    }

    $: if (episodes.length > 0) {
        episodePage = Math.min(
            Math.max(episodePage, 1),
            Math.max(totalPages, 1),
        );
    }

    $: if (episodes.length === 0) {
        episodePage = 1;
    }

    $: pageStart = (episodePage - 1) * EPISODES_PER_PAGE;
    $: pageEndExclusive = Math.min(
        pageStart + EPISODES_PER_PAGE,
        effectiveTotalEpisodes,
    );
    $: pageSize = Math.max(0, pageEndExclusive - pageStart);
    $: pagedEntries = Array.from({ length: pageSize }, (_, offset) => {
        const index = pageStart + offset;
        const episode = episodes[index];
        return {
            episode,
            fallbackNumber: index + 1,
        };
    });

    $: requiredCountForPage = pageEndExclusive;
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
        dispatch("loadMore", { requiredCount: requiredCountForPage });
    }

    function onNextPage() {
        if (episodePage < totalPages) {
            episodePage += 1;
            return;
        }
        if (canLoadMore && !loadingMore) {
            const fallbackRequiredCount = episodes.length + EPISODES_PER_PAGE;
            lastRequestedRequiredCount = fallbackRequiredCount;
            dispatch("loadMore", { requiredCount: fallbackRequiredCount });
        }
    }
</script>

{#if episodes.length}
    <section class="grid gap-3 min-w-0">
        <div class="flex items-center justify-between gap-2">
            <h2 class="section-title">Episodes</h2>
            <div class="flex items-center gap-2">
                <span class="text-[12px] text-white/40">
                    Page {episodePage} / {totalPages}
                </span>
                <button
                    class="chevron-btn"
                    disabled={episodePage <= 1}
                    onclick={() => episodePage--}
                >
                    <ArrowLeftIcon size={14} weight="bold" />
                </button>
                <button
                    class="chevron-btn"
                    disabled={(episodePage >= totalPages && !canLoadMore) ||
                        loadingMore}
                    onclick={onNextPage}
                >
                    <ArrowRightIcon size={14} weight="bold" />
                </button>
            </div>
        </div>

        <div class="grid grid-cols-5 gap-3 max-[760px]:grid-cols-2">
            {#each pagedEntries as entry (entry.fallbackNumber)}
                {#if entry.episode}
                    <a
                        href="/watch/{anime_id}?ep={entry.episode.number}"
                        class="grid gap-1.5 rounded-xl p-1.5
                               no-underline text-inherit transition-colors min-w-0
                               hover:bg-white/7 hover:border-white/12"
                    >
                        <div
                            class="w-full aspect-video rounded-lg overflow-hidden border border-white/8 bg-black/20"
                        >
                            <img
                                src={entry.episode.thumbnail ?? cover_image}
                                alt={entry.episode.title ??
                                    `Episode ${entry.episode.number}`}
                                class="w-full h-full object-cover"
                                loading="lazy"
                            />
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
            <p class="text-[12px] text-white/45">Loading more episodes...</p>
        {/if}
    </section>
{/if}