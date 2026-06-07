<script lang="ts">
    import { onMount } from 'svelte'
    import { fade } from 'svelte/transition'
    import { getTrending, getPopular, getTopRated, getHomeGenres, HOME_GENRES } from '$lib/api/anime'
    import { libraryResume } from '$lib/api/library'
    import type { AnimeSummary } from '$lib/types/anime'
    import type { LibraryEntry } from '$lib/types/library'
    import AnimeCarousel from '$lib/components/home/AnimeCarousel.svelte'
    import ContinueWatchingTeaser from '$lib/components/home/ContinueWatchingTeaser.svelte'
    import AnimeRow from '$lib/components/shared/AnimeRow.svelte'
    import ContinueWatchingRow from '$lib/components/home/ContinueWatchingRow.svelte'
    import LoadingScreen from '$lib/components/shared/LoadingScreen.svelte'

    let trending:  AnimeSummary[] = []
    let popular:   AnimeSummary[] = []
    let topRated:  AnimeSummary[] = []
    let genreRows: Record<string, AnimeSummary[]> = {}

    let trendingReady  = false
    let popularReady   = false
    let topRatedReady  = false
    let genresReady    = false

    let continueWatching: LibraryEntry[] = []
    let teaserEntry: LibraryEntry | null = null
    let teaserEpisode = 0

    let error: string | null = null

    function handleContinueHover(entry: LibraryEntry | null, episode: number) {
        teaserEntry = entry
        teaserEpisode = episode
    }

    onMount(async () => {
        try {
            const all = await libraryResume()
            continueWatching = all.filter(
                (e) =>
                    e.status === 'WATCHING' &&
                    e.progress > 0 &&
                    (e.episode_total == null || e.progress < e.episode_total),
            )
        } catch {}

        // Load sequentially — avoids a 4-request burst that triggers AniList 429
        try { trending  = await getTrending();  trendingReady  = true } catch (e) { error = String(e); return }
        try { popular   = await getPopular();   popularReady   = true } catch (e) { error = String(e) }
        try { topRated  = await getTopRated();  topRatedReady  = true } catch (e) { error = String(e) }
        try { genreRows = await getHomeGenres(); genresReady   = true } catch (e) { error = String(e) }
    })
</script>

{#if !trendingReady && !error}
    <LoadingScreen label="Loading home feed..." fullscreen={false} className="min-h-[70vh]" />
{:else if error && !trendingReady}
    <p class="px-6 pt-20 text-center text-red-400">{error}</p>
{:else}
    <!-- Hero: swaps between carousel and continue-watching teaser on hover -->
    <div class="relative w-full overflow-hidden" style="height: clamp(460px, 68vh, 860px)">
        {#if teaserEntry}
            <div class="absolute inset-0" in:fade={{ duration: 220 }}>
                <ContinueWatchingTeaser entry={teaserEntry} episode={teaserEpisode} />
            </div>
        {:else}
            <div class="absolute inset-0" in:fade={{ duration: 220 }}>
                <AnimeCarousel items={trending.slice(0, 8)} />
            </div>
        {/if}
    </div>

    <main class="px-6 pt-8 pb-8 space-y-8">

        {#if continueWatching.length > 0}
            <ContinueWatchingRow items={continueWatching} onHoverChange={handleContinueHover} />
        {/if}

        {#if trendingReady}
            <AnimeRow titleClass="text-lg font-semibold" title="Trending Now" items={trending} />
        {/if}
        {#if popularReady}
            <AnimeRow titleClass="text-lg font-semibold" title="All Time Popular" items={popular} />
        {/if}
        {#if topRatedReady}
            <AnimeRow titleClass="text-lg font-semibold" title="Top Rated" items={topRated} />
        {/if}
        {#if genresReady}
            {#each HOME_GENRES as genre}
                {#if genreRows[genre]?.length}
                    <AnimeRow titleClass="text-lg font-semibold" title={genre} items={genreRows[genre]} />
                {/if}
            {/each}
        {/if}

        {#if error}
            <p class="text-sm text-red-400/70">{error}</p>
        {/if}
    </main>
{/if}
