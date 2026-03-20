<script lang="ts">
    import type { Episode } from '$lib/types/anime'
    import { ArrowLeftIcon, ArrowRightIcon } from 'phosphor-svelte'
    import { EPISODES_PER_PAGE } from '$lib/constants/ui'

    export let episodes: Episode[]
    export let cover_image: string
    export let anime_id: number

    let episodePage = 1

    $: totalPages = Math.ceil(episodes.length / EPISODES_PER_PAGE)

    $: pagedEpisodes = episodes.slice(
        (episodePage - 1) * EPISODES_PER_PAGE,
        episodePage * EPISODES_PER_PAGE
    )
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
                    disabled={episodePage >= totalPages}
                    onclick={() => episodePage++}
                >
                    <ArrowRightIcon size={14} weight="bold" />
                </button>
            </div>
        </div>

        <div class="grid grid-cols-5 gap-3 max-[760px]:grid-cols-2">
            {#each pagedEpisodes as episode}
                <a
                    href="/watch/{anime_id}?ep={episode.number}"
                    class="grid gap-1.5 rounded-xl p-1.5
                           no-underline text-inherit transition-colors min-w-0
                           hover:bg-white/7 hover:border-white/12"
                >
                    <div class="w-full aspect-video rounded-lg overflow-hidden border border-white/8 bg-black/20">
                        <img
                            src={episode.thumbnail ?? cover_image}
                            alt={episode.title ?? `Episode ${episode.number}`}
                            class="w-full h-full object-cover"
                            loading="lazy"
                        />
                    </div>
                    <div class="grid gap-0.5 px-0.5 pb-1">
                        <p class="text-[11px] uppercase tracking-wide text-white/40 m-0">
                            EP {episode.number}
                        </p>
                        <h3 class="text-[13px] font-medium m-0 line-clamp-1 leading-snug">
                            {episode.title ?? `Episode ${episode.number}`}
                        </h3>
                    </div>
                </a>
            {/each}
        </div>
    </section>
{/if}