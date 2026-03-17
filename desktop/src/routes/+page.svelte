<script lang="ts">
    import { onMount } from 'svelte'
    import { getTrending, getPopular, getTopRated, getHomeGenres, HOME_GENRES } from '$lib/api/anime'
    import type { AnimeSummary } from '$lib/types/anime'
    import AnimeRow from '$lib/components/AnimeRow.svelte'

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
    <p class="state">Loading...</p>
{:else if error}
    <p class="state error">{error}</p>
{:else}
    <main>
        <AnimeRow title="Trending Now"     items={trending} />
        <AnimeRow title="All Time Popular" items={popular} />
        <AnimeRow title="Top Rated"        items={topRated} />

        {#each HOME_GENRES as genre}
            {#if genreRows[genre]?.length}
                <AnimeRow title={genre} items={genreRows[genre]} />
            {/if}
        {/each}
    </main>
{/if}

<style>
    main {
        padding: 24px;
    }

    .state {
        text-align: center;
        padding: 48px;
        opacity: 0.5;
    }

    .error {
        color: red;
    }
</style>