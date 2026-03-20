<script lang="ts">
    import { page } from '$app/stores'
    import { goto } from '$app/navigation'
    import { onDestroy } from 'svelte'
    import VideoPlayer from '$lib/components/player/VideoPlayer.svelte'
    import EpisodeGrid from '$lib/components/player/EpisodeGrid.svelte'
    import { getAnimeDetails } from '$lib/api/anime'
    import { streamSearch, streamEpisodes, streamSources } from '$lib/api/stream'
    import type { AnimeDetails } from '$lib/types/anime'
    import type { StreamableAnime, StreamingEpisode, StreamSource, ProviderKind } from '$lib/types/stream'

    const PROVIDER_OPTIONS: { label: string; value: ProviderKind }[] = [
        { label: 'AllAnime',  value: 'allanime'  },
        { label: 'AnimePahe', value: 'animepahe' },
        { label: 'Anizone',   value: 'anizone'   },
        { label: 'Anidap',    value: 'anidap'    },
    ]

    let details: AnimeDetails | null = null
    let pageLoading = true
    let pageError: string | null = null

    let provider: ProviderKind = 'animepahe'
    let streamAnime: StreamableAnime | null = null
    let episodes: StreamingEpisode[] = []
    let selectedEpisode: StreamingEpisode | null = null

    let sources: StreamSource[] = []
    let selectedSource: StreamSource | null = null
    let playbackUrl: string | null = null
    let sourceKind: string = 'hls'

    let bootstrapping = false
    let episodesLoading = false
    let sourcesLoading = false
    let statusMessage = ''
    let mediaError = ''

    let autoPlay = true
    let autoNext = true
    let focusMode = false

    let fillerNumbers: Set<number> = new Set()
    let recapNumbers:  Set<number> = new Set()

    $: animeId = $page.params.id
    $: requestedEp = Number($page.url.searchParams.get('ep') ?? '1')

    $: episodeNumbers = details?.episode_count
        ? Array.from({ length: details.episode_count }, (_, i) => i + 1)
        : episodes.map(e => Number(e.number)).filter(n => n > 0).sort((a, b) => a - b)

    $: selectedNumber = Number(selectedEpisode?.number ?? requestedEp)

    $: providerLabel = PROVIDER_OPTIONS.find(p => p.value === provider)?.label ?? 'AnimePahe'

    $: if (animeId) bootstrap(animeId, requestedEp)

    async function bootstrap(id: string, targetEp: number) {
        pageLoading = true
        pageError = null
        mediaError = ''
        try {
            details = await getAnimeDetails(Number(id))

            // Fetch jikan filler data in background — don't block on it
            if (details?.id_mal) {
                fetchJikanFiller(details.id_mal)
            }

            await bootstrapProvider(details?.title ?? '', targetEp)
        } catch (e) {
            pageError = String(e)
        } finally {
            pageLoading = false
        }
    }

    async function fetchJikanFiller(malId: number) {
        try {
            const res = await fetch(`https://api.jikan.moe/v4/anime/${malId}/episodes`)
            const json = await res.json()
            const data = json.data ?? []
            fillerNumbers = new Set(data.filter((e: any) => e.filler).map((e: any) => e.mal_id as number))
            recapNumbers  = new Set(data.filter((e: any) => e.recap).map((e: any) => e.mal_id as number))
        } catch {
            // filler data is non-critical — silently ignore failures
        }
    }

    async function bootstrapProvider(titleHint: string, targetEp: number) {
        bootstrapping = true
        episodesLoading = true
        statusMessage = `Searching ${providerLabel}...`
        mediaError = ''

        try {
            const results = await streamSearch(provider, titleHint)
            streamAnime = pickBestMatch(results, titleHint)

            if (!streamAnime) {
                statusMessage = 'No stream result found for this title.'
                episodesLoading = false
                bootstrapping = false
                return
            }

            const epList = await streamEpisodes(provider, streamAnime)
            episodes = epList
            episodesLoading = false
            statusMessage = `Episodes loaded.`

            await selectAndPlay(targetEp)
        } catch (e) {
            mediaError = String(e)
            statusMessage = ''
            episodesLoading = false
        } finally {
            bootstrapping = false
        }
    }

    async function switchProvider(next: ProviderKind) {
        provider = next
        if (!details) return
        const currentEp = Number(selectedEpisode?.number ?? 1)
        playbackUrl = null
        selectedSource = null
        sources = []
        await bootstrapProvider(details.title, currentEp)
    }

    async function selectAndPlay(number: number) {
        if (!streamAnime) return

        const ep: StreamingEpisode = episodes.find(e => Number(e.number) === number) ?? {
            anime_id: streamAnime.id,
            number: String(number),
            source_id: null,
        }

        selectedEpisode = ep
        await loadSources(ep)

        // update URL without re-triggering bootstrap
        const url = new URL(window.location.href)
        url.searchParams.set('ep', String(number))
        window.history.replaceState({}, '', url.toString())
    }

    async function loadSources(ep: StreamingEpisode) {
        sourcesLoading = true
        mediaError = ''
        statusMessage = `Loading sources for EP ${ep.number}...`
        playbackUrl = null

        try {
            const result = await streamSources(provider, ep, null)
            sources = result
            selectedSource = pickBestSource(result)

            if (!selectedSource) {
                statusMessage = 'No sources found for this episode.'
                return
            }

            statusMessage = autoPlay ? 'Starting playback...' : 'Ready. Press play to start.'
            playbackUrl = selectedSource.url
            sourceKind = selectedSource.kind
        } catch (e) {
            mediaError = String(e)
            statusMessage = ''
        } finally {
            sourcesLoading = false
        }
    }

    async function playEpisode(number: number) {
        playbackUrl = null
        await selectAndPlay(number)
    }

    async function playNext() {
        const idx = episodeNumbers.indexOf(selectedNumber)
        const next = episodeNumbers[idx + 1]
        if (next) await playEpisode(next)
    }

    async function playPrev() {
        const idx = episodeNumbers.indexOf(selectedNumber)
        const prev = episodeNumbers[idx - 1]
        if (prev) await playEpisode(prev)
    }

    async function onSourceChange(src: StreamSource) {
        selectedSource = src
        playbackUrl = src.url
        sourceKind = src.kind
    }

    function pickBestMatch(results: StreamableAnime[], hint: string): StreamableAnime | null {
        if (results.length === 0) return null
        const token = hint.toLowerCase().trim()
        return (
            results.find(r => r.title.toLowerCase() === token) ??
            results.find(r => r.title.toLowerCase().includes(token)) ??
            results[0]
        )
    }

    function pickBestSource(pool: StreamSource[]): StreamSource | null {
        if (pool.length === 0) return null
        return pool.find(s => s.kind.toLowerCase().includes('hls')) ?? pool[0]
    }

    onDestroy(() => {
    })
</script>

    {#if pageLoading}
        <div class="min-h-screen bg-black grid place-items-center">
            <div class="h-8 w-8 animate-spin rounded-full border-2 border-white/20 border-t-white"></div>
        </div>

    {:else if pageError}
        <div class="min-h-screen bg-black grid place-items-center">
            <div class="text-center grid gap-3">
                <p class="text-red-400">{pageError}</p>
                <button
                    class="text-sm text-white/50 hover:text-white transition-colors"
                    onclick={() => goto(`/anime/${animeId}`)}
                >
                    ← Back to anime
                </button>
            </div>
        </div>

    {:else if details}
        <div class="relative min-h-screen bg-black">

            {#if focusMode}
            <button
                type="button"
                class="fixed inset-0 z-[70] bg-black/75 backdrop-blur-[1px] border-0"
                aria-label="Exit focus mode"
                onclick={() => (focusMode = false)}
            ></button>
            {/if}

            <div class="grid xl:grid-cols-[minmax(0,1fr)_minmax(390px,430px)] gap-4
                        px-4 pt-16 pb-6
                        xl:h-[calc(100vh-3.5rem)] xl:overflow-hidden">

                <!-- ── Left: Player ───────────────────────────────────────────── -->
                <div class="flex flex-col gap-0 min-h-0 {focusMode ? 'relative z-[69]' : ''}">

                    <VideoPlayer
                        {sources}
                        {selectedSource}
                        {playbackUrl}
                        {sourceKind}
                        {selectedEpisode}
                        {autoPlay}
                        {autoNext}
                        {focusMode}
                        animeTitle={details.title}
                        {provider}
                        providerOptions={PROVIDER_OPTIONS}
                        loading={bootstrapping || sourcesLoading}
                        {statusMessage}
                        {mediaError}
                        on:sourceChange={e => onSourceChange(e.detail)}
                        on:providerChange={e => switchProvider(e.detail as ProviderKind)}
                        on:toggleAutoPlay={() => autoPlay = !autoPlay}
                        on:toggleAutoNext={() => autoNext = !autoNext}
                        on:toggleFocus={() => focusMode = !focusMode}
                        on:playNext={playNext}
                        on:playPrev={playPrev}
                        on:ended={() => { if (autoNext) playNext() }}
                    />
                </div>

                <!-- ── Right: Episodes ────────────────────────────────────────── -->
                {#if !focusMode}
                    <div class="flex flex-col gap-3 min-h-0 rounded-xl p-2 xl:overflow-hidden">
                        <EpisodeGrid
                            {episodeNumbers}
                            {fillerNumbers}
                            {recapNumbers}
                            {selectedNumber}
                            loading={bootstrapping || episodesLoading}
                            on:select={e => playEpisode(e.detail)}
                        />
                    </div>
                {/if}

            </div>
        </div>
    {/if}
