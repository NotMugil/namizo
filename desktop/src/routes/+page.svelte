<script lang="ts">
    import { onMount } from 'svelte'
    import { getTrending, getPopular, getTopRated, getHomeGenres, getAnimeDetails, HOME_GENRES } from '$lib/api/anime'
    import type { AnimeSummary } from '$lib/types/anime'
    import AnimeCarousel from '$lib/components/AnimeCarousel.svelte'
    import AnimeRow from '$lib/components/AnimeRow.svelte'
    import LoadingScreen from '$lib/components/shared/LoadingScreen.svelte'

    let trending:  AnimeSummary[] = []
    let popular:   AnimeSummary[] = []
    let topRated:  AnimeSummary[] = []
    let genreRows: Record<string, AnimeSummary[]> = {}

    let loading = true
    let error: string | null = null

    onMount(async () => {
        try {
            // fixed rows fire concurrently
            [trending, popular, topRated, genreRows] = await Promise.all([
                getTrending(),
                getPopular(),
                getTopRated(),
                getHomeGenres(),
            ])
        } catch (e) {
            error = String(e)
        } finally {
            loading = false
        }
    })
</script>

{#if loading}
    <LoadingScreen label="Loading home feed..." fullscreen={false} className="min-h-[70vh]" />
{:else if error}
    <p class="px-6 pt-20 text-center text-red-400">{error}</p>
{:else}
<AnimeCarousel items={trending.slice(0, 8)} />
    <main class="px-6 pt-8 pb-8 space-y-8">

        <AnimeRow titleClass="text-lg font-semibold" title="Trending Now"     items={trending} />
        <AnimeRow titleClass="text-lg font-semibold" title="All Time Popular" items={popular} />
        <AnimeRow titleClass="text-lg font-semibold" title="Top Rated"        items={topRated} />

        {#each HOME_GENRES as genre}
            {#if genreRows[genre]?.length}
                <AnimeRow titleClass="text-lg font-semibold" title={genre} items={genreRows[genre]} />
            {/if}
        {/each}
    </main>
{/if}