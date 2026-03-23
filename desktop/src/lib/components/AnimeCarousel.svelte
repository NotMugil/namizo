<script lang="ts" context="module">
    const carouselBackgroundCache = new Map<string, string | null>()
    const carouselBackgroundRequests = new Map<string, Promise<string | null>>()
</script>

<script lang="ts">
    import { onMount, onDestroy } from 'svelte'
    import { goto } from '$app/navigation'
    import { PlayIcon, InfoIcon, ArrowLeftIcon, ArrowRightIcon, PlusIcon } from 'phosphor-svelte'
    import type { AnimeSummary } from '$lib/types/anime'
    import TrailerSurface from '$lib/components/shared/TrailerSurface.svelte'
    import LibraryEntryEditor from '$lib/components/library/LibraryEntryEditor.svelte'
    import type { LibraryEntry } from '$lib/types/library'
    import {
        cacheLibraryEntry,
        draftLibraryFromSummary,
        getLibraryStatus,
        resolveLibraryEntryWithState,
    } from '$lib/utils/library'
    import { BRANDING_DELAY } from '$lib/constants/ui'
    import { getTvdbBackground } from '$lib/api/tvdb'

    export let items: AnimeSummary[] = []

    let current = 0
    let timer: ReturnType<typeof setInterval> | null = null
    let paused = false
    let trailerMounted = false
    let showTrailer = false
    let trailerTimer: ReturnType<typeof setTimeout> | null = null
    let editorOpen = false
    let selectedEntry: LibraryEntry | null = null
    let tvdbBackgroundImage: string | null = null
    let backgroundRequestVersion = 0
    let currentItemInCollection = false
    let collectionStatusRequestVersion = 0

    $: item = items[current] ?? null
    $: totalItems = Math.min(items.length, 8) // cap at 8 for carousel
    $: activeBackgroundImage = tvdbBackgroundImage ?? item?.banner_image ?? item?.cover_image ?? ''

    $: {
        current
        resetTrailer()
        startTrailerTimer()
    }

    $: if (item) {
        tvdbBackgroundImage = null
        void resolveBackgroundImage(item)
        void resolveCollectionStatus(item.id)
    }

    $: if (items.length > 0) {
        preloadCarouselBackgrounds(items.slice(0, totalItems))
    }

    function resetTrailer() {
        if (trailerTimer) clearTimeout(trailerTimer)
        showTrailer = false
        trailerMounted = false
    }

    function startTrailerTimer() {
        const slideItem = items[current]
        if (!slideItem?.trailer_id) return
        trailerMounted = true

        trailerTimer = setTimeout(() => {
            showTrailer = true
        }, BRANDING_DELAY)
    }

    function next() {
        current = (current + 1) % totalItems
    }

    function prev() {
        current = (current - 1 + totalItems) % totalItems
    }

    function goTo(index: number) {
        current = index
        resetTimer()
    }

    function resetTimer() {
        if (timer) clearInterval(timer)
        if (!paused) {
            timer = setInterval(next, 15000)
        }
    }

    onMount(() => {
        timer = setInterval(next, 15000)
    })

    onDestroy(() => {
        if (timer) clearInterval(timer)
        if (trailerTimer) clearTimeout(trailerTimer)
    })

    function formatScore(score: number | null): string {
        if (!score) return ''
        return (score / 10).toFixed(1)
    }

    function backgroundKey(slide: AnimeSummary): string {
        return `${slide.id}|${(slide.format ?? '').trim().toUpperCase()}`
    }

    function preloadCarouselBackgrounds(slides: AnimeSummary[]) {
        for (const slide of slides) {
            void fetchBackgroundCached(slide)
        }
    }

    function fetchBackgroundCached(slide: AnimeSummary): Promise<string | null> {
        const key = backgroundKey(slide)
        const cached = carouselBackgroundCache.get(key)
        if (cached !== undefined) {
            return Promise.resolve(cached)
        }

        const inFlight = carouselBackgroundRequests.get(key)
        if (inFlight) {
            return inFlight
        }

        const request = getTvdbBackground(slide.id, slide.format ?? null)
            .then((value) => value ?? null)
            .catch(() => null)
            .then((value) => {
                carouselBackgroundCache.set(key, value)
                carouselBackgroundRequests.delete(key)
                return value
            })

        carouselBackgroundRequests.set(key, request)
        return request
    }

    async function resolveBackgroundImage(slide: AnimeSummary) {
        const requestVersion = ++backgroundRequestVersion
        const resolved = await fetchBackgroundCached(slide)
        if (requestVersion === backgroundRequestVersion && item?.id === slide.id) {
            tvdbBackgroundImage = resolved
        }
    }

    async function openCollectionEditor() {
        if (!item) return
        const fallback = draftLibraryFromSummary(item)
        try {
            const resolved = await resolveLibraryEntryWithState(fallback)
            selectedEntry = resolved.entry
            currentItemInCollection = resolved.exists
        } catch {
            selectedEntry = fallback
            currentItemInCollection = false
        }
        editorOpen = true
    }

    function onEditorSaved(event: CustomEvent<LibraryEntry>) {
        selectedEntry = event.detail
        currentItemInCollection = true
        cacheLibraryEntry(event.detail)
        editorOpen = false
    }

    async function resolveCollectionStatus(anilistId: number) {
        const requestVersion = ++collectionStatusRequestVersion
        try {
            const status = await getLibraryStatus(anilistId)
            if (requestVersion !== collectionStatusRequestVersion || item?.id !== anilistId) return
            currentItemInCollection = Boolean(status)
        } catch {
            if (requestVersion !== collectionStatusRequestVersion || item?.id !== anilistId) return
            currentItemInCollection = false
        }
    }
</script>

{#if item}
    <div
        class="relative w-full overflow-hidden"
        style="height: clamp(460px, 68vh, 860px)"
        aria-label="Featured anime carousel"
        role="region"
        onmouseenter={() => { paused = true; if (timer) clearInterval(timer) }}
        onmouseleave={() => { paused = false; resetTimer() }}
    >
        <!-- Background image -->
        <div class="absolute inset-0">
            <img
                src={activeBackgroundImage}
                alt={item.title}
                class="absolute inset-0 z-0 w-full h-full object-cover scale-110 brightness-50
                       transition-opacity duration-700
                       {showTrailer ? 'opacity-0' : 'opacity-100'}"
            />

            <!-- iframe mounts early (buffering), but stays hidden until branding clears -->
            {#if trailerMounted && item.trailer_id}
                {#key `${item.id}:${item.trailer_id}`}
                    <div class="absolute inset-0 z-0 transition-opacity duration-700
                                {showTrailer ? 'opacity-100' : 'opacity-0'}">
                        <TrailerSurface
                            image={activeBackgroundImage}
                            trailerId={item.trailer_id}
                            loadDelay={0}
                            brandingDelay={0}
                        />
                    </div>
                {/key}
            {/if}
            <div
                class="pointer-events-none absolute inset-0 z-10 bg-gradient-to-r from-black/90 via-black/40 to-transparent"
            ></div>
            <div
                class="pointer-events-none absolute inset-0 z-10 bg-gradient-to-t from-black via-background/20 to-transparent"
            ></div>
        </div>

        <div class="relative z-20 flex h-full items-end pb-8 px-8 gap-6">

            <!-- Cover -->
            <img
                src={item.cover_image}
                alt={item.title}
                class="hidden sm:block md: h-[200px] lg:h-[300px] aspect-[2/3] object-cover rounded-lg
                       border border-white/10 shadow-xl shrink-0 self-end"
            />

            <div class="flex flex-col gap-2 min-w-0 max-w-[520px]">
                <div class="flex gap-1.5 flex-wrap">
                    {#if item.format}
                        <span class="chip">{item.format}</span>
                    {/if}
                    {#if item.average_score}
                        <span class="chip">★ {formatScore(item.average_score)}</span>
                    {/if}
                    {#if item.episodes}
                        <span class="chip">{item.episodes} EPS</span>
                    {/if}
                    {#each item.genres.slice(0, 2) as genre}
                        <span class="chip">{genre}</span>
                    {/each}
                </div>

                <!-- Title -->
                <h2 class="text-[clamp(1.3rem,3vw,2rem)] font-bold leading-tight line-clamp-2 m-0">
                    {item.title}
                </h2>

                {#if item.description}
                    <p class="m-0 text-white/60 text-[0.82rem] leading-[1.5] max-w-[520px]
                            overflow-y-auto [max-height:calc(1.5em*3)]
                            [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
                        {@html item.description}
                    </p>
                {/if}

                <!-- Actions -->
                <div class="flex gap-2 mt-1">
                    <a
                        href="/watch/{item.id}?ep=1"
                        class="inline-flex items-center gap-1.5 h-9 px-4 rounded-lg
                               bg-white text-black text-[0.82rem] font-semibold
                               no-underline transition-opacity hover:opacity-90"
                    >
                        <PlayIcon size={14} weight="fill" />
                        Watch Now
                    </a>
                    <a
                        href="/anime/{item.id}"
                        class="inline-flex items-center gap-1.5 h-9 px-4 rounded-lg
                               border border-white/20 bg-white/10 text-white
                               text-[0.82rem] font-medium no-underline
                               transition-colors hover:bg-white/15"
                    >
                        <InfoIcon size={14} weight="bold" />
                        Details
                    </a>
                    <button
                        type="button"
                        class="inline-flex items-center gap-1.5 h-9 px-4 rounded-lg
                               border border-white/20 bg-white/10 text-white
                               text-[0.82rem] font-medium
                               transition-colors hover:bg-white/15"
                        onclick={openCollectionEditor}
                    >
                        <PlusIcon size={14} weight="bold" />
                        {currentItemInCollection ? 'Edit Entry' : 'Add to Collection'}
                    </button>
                </div>
            </div>
        </div>

        <div class="absolute bottom-3 right-6 z-20 flex flex-col items-end gap-3">
            <div class="flex gap-1">
                <button class="chevron-btn" onclick={prev} aria-label="Previous">
                    <ArrowLeftIcon />
                </button>
                <button class="chevron-btn" onclick={next} aria-label="Next">
                    <ArrowRightIcon/>
                </button>
            </div>

            <div class="flex gap-1.5">
                {#each Array.from({ length: totalItems }) as _, i}
                    <button
                        class="h-1.5 rounded-full transition-all duration-300 border-0
                            {i === current ? 'w-5 bg-white' : 'w-1.5 bg-white/35 hover:bg-white/55'}"
                        onclick={() => goTo(i)}
                        aria-label="Go to slide {i + 1}"
                    ></button>
                {/each}
            </div>
        </div>
    </div>
{/if}

<LibraryEntryEditor bind:open={editorOpen} entry={selectedEntry} on:saved={onEditorSaved} />