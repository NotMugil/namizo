<script lang="ts">
    import { onMount } from 'svelte'
    import { PlayIcon, ArrowLeftIcon, ArrowRightIcon } from 'phosphor-svelte'
    import type { LibraryEntry } from '$lib/types/library'
    import { getTvdbEpisodes } from '$lib/api/tvdb'

    export let items: LibraryEntry[] = []
    export let onHoverChange: ((entry: LibraryEntry | null, episode: number) => void) | undefined = undefined

    // Card width + gap (used to calculate scroll distance)
    const CARD_W = 308
    const GAP = 16

    let scrollEl: HTMLDivElement
    let canScrollLeft = false
    let canScrollRight = false

    function syncButtons() {
        if (!scrollEl) return
        canScrollLeft  = scrollEl.scrollLeft > 4
        canScrollRight = scrollEl.scrollLeft + scrollEl.clientWidth < scrollEl.scrollWidth - 4
    }

    function scrollBy(dir: -1 | 1) {
        scrollEl?.scrollBy({ left: dir * (CARD_W + GAP) * 2, behavior: 'smooth' })
    }

    onMount(() => {
        syncButtons()
        for (const entry of items) {
            const ep = nextEp(entry)
            getTvdbEpisodes(entry.anilist_id, entry.format)
                .then((episodes) => {
                    const match = episodes.find((e) => e.number === ep)
                    episodeThumbs = { ...episodeThumbs, [entry.anilist_id]: match?.thumbnail ?? null }
                })
                .catch(() => {
                    episodeThumbs = { ...episodeThumbs, [entry.anilist_id]: null }
                })
        }
    })

    function nextEp(entry: LibraryEntry): number {
        const next = entry.progress + 1
        if (entry.episode_total != null && next > entry.episode_total) return entry.episode_total
        return next
    }

    function epLabel(entry: LibraryEntry): string {
        const ep = nextEp(entry)
        return entry.episode_total ? `Episode ${ep} / ${entry.episode_total}` : `Episode ${ep}`
    }

    // undefined = not yet fetched, null = fetched but no thumbnail available
    let episodeThumbs: Record<number, string | null | undefined> = {}
</script>

<section>
    <div class="flex items-center justify-between mb-3">
        <h2 class="text-lg font-semibold text-white">Continue Watching</h2>
        <div class="flex gap-1">
            <button
                type="button"
                onclick={() => scrollBy(-1)}
                disabled={!canScrollLeft}
                class="chevron-btn"
                aria-label="Scroll left"
            >
                <ArrowLeftIcon size={14} weight="bold" />
            </button>
            <button
                type="button"
                onclick={() => scrollBy(1)}
                disabled={!canScrollRight}
                class="chevron-btn"
                aria-label="Scroll right"
            >
                <ArrowRightIcon size={14} weight="bold" />
            </button>
        </div>
    </div>

    <div
        bind:this={scrollEl}
        onscroll={syncButtons}
        class="flex gap-4 overflow-x-auto pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
    >
        {#each items as entry (entry.anilist_id)}
            {@const ep = nextEp(entry)}
            {@const _thumb = episodeThumbs[entry.anilist_id]}
            <a
                href="/watch/{entry.anilist_id}?ep={ep}"
                class="group shrink-0 flex flex-col gap-2 rounded-lg"
                style="width: clamp(200px, 72vw, {CARD_W}px)"
                onmouseenter={() => { if (window.matchMedia('(hover: hover)').matches) onHoverChange?.(entry, ep) }}
                onmouseleave={() => { if (window.matchMedia('(hover: hover)').matches) onHoverChange?.(null, 0) }}
                aria-label="Continue watching {entry.title}, Episode {ep}"
            >
                <!-- 16:9 episode thumbnail -->
                <div class="relative w-full overflow-hidden rounded-xl bg-white/5" style="aspect-ratio: 16/9">
                    <img
                        src={_thumb != null ? _thumb : (entry.banner_image ?? entry.cover_image ?? '')}
                        alt="Episode {ep}"
                        class="w-full h-full object-cover brightness-90
                               sm:group-hover:brightness-60 transition-[filter] duration-300"
                    />
                    <!-- Play button (hover only) -->
                    <div class="absolute inset-0 hidden sm:flex items-center justify-center
                                opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                        <div class="flex h-12 w-12 items-center justify-center rounded-full
                                    bg-black/50 backdrop-blur-sm border border-white/25">
                            <PlayIcon size={22} weight="fill" class="text-white ml-0.5" />
                        </div>
                    </div>
                </div>

                <!-- Text below thumbnail -->
                <div>
                    <p class="text-white text-[0.84rem] font-medium leading-snug line-clamp-1">
                        {entry.title}
                    </p>
                    <p class="text-white/45 text-[0.75rem] mt-0.5">{epLabel(entry)}</p>
                </div>
            </a>
        {/each}
    </div>
</section>
