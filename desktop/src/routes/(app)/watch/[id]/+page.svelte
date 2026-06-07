<script lang="ts">
    import { page } from '$app/stores'
    import { goto, replaceState } from '$app/navigation'
    import { onDestroy } from 'svelte'
    import VideoPlayer from '$lib/components/player/VideoPlayer.svelte'
    import EpisodeSidebar from '$lib/components/player/EpisodeSidebar.svelte'
    import EpisodeInfo from '$lib/components/player/EpisodeInfo.svelte'
    import RecommendationCard from '$lib/components/player/RecommendationCard.svelte'
    import LoadingScreen from '$lib/components/shared/LoadingScreen.svelte'
    import { breadcrumb } from '$lib/state.svelte'
    import { getAnimeDetails } from '$lib/api/anime'
    import { getJikanEpisodes } from '$lib/api/jikan'
    import { logToTerminal } from '$lib/api/logging'
    import { getTvdbEpisodes } from '$lib/api/tvdb'
    import { BellSimpleRingingIcon } from 'phosphor-svelte'
    import { playbackStart, playbackStop } from '$lib/api/playback'
    import { getEpisodeSources } from '$lib/api/stream'
    import type { AnimeDetails } from '$lib/types/anime'
    import type { StreamSource } from '$lib/types/stream'
    import {
        buildAniListEpisodeNumbers,
        buildAniListTitleMap,
        episodeTitleForNumber as resolveEpisodeTitleForNumber,
        parseEpisodeNumber,
        parseRequestedEpisode,
    } from '$lib/utils/watch/episodes'

    const PROVIDER_OPTIONS = [
        { label: 'Sub', value: 'sub' },
        { label: 'Dub', value: 'dub' },
    ]

    let audioMode: 'sub' | 'dub' = 'sub'

    let details: AnimeDetails | null = null
    let pageLoading = true
    let pageError: string | null = null

    let selectedEpisodeNumber: number | null = null
    let sources: StreamSource[] = []
    let selectedSource: StreamSource | null = null
    let playbackUrl: string | null = null
    let sourceKind: string = 'hls'
    let playbackSessionId: string | null = null

    let sourcesLoading = false
    let statusMessage = ''
    let mediaError = ''
    let debugLines: string[] = []
    let playbackProgressSeen = false

    let autoPlay = true
    let autoNext = true
    let focusMode = false
    let theatreMode = false

    let fillerNumbers: Set<number> = new Set()
    let recapNumbers: Set<number> = new Set()
    let episodeTitleByNumber: Record<number, string> = {}
    let episodeThumbnailByNumber: Record<number, string | null> = {}

    $: animeId = $page.params.id
    $: requestedEp = parseRequestedEpisode($page.url.searchParams.get('ep'))
    $: episodeNumbers = buildAniListEpisodeNumbers(details?.episode_count ?? null, [])
    $: selectedNumber = selectedEpisodeNumber ?? requestedEp
    $: selectedEpisodeTitle = (() => {
        if (!selectedEpisodeNumber) return 'Select Episode'
        return episodeTitleForNumber(selectedEpisodeNumber)
    })()

    $: if (animeId) bootstrap(animeId, requestedEp)

    function episodeTitleForNumber(number: number): string {
        return resolveEpisodeTitleForNumber(episodeTitleByNumber, number)
    }

    async function bootstrap(id: string, targetEp: number) {
        pageLoading = true
        pageError = null
        mediaError = ''
        statusMessage = ''

        await stopActivePlayback()

        selectedEpisodeNumber = null
        sources = []
        selectedSource = null
        playbackUrl = null
        sourceKind = 'hls'
        fillerNumbers = new Set()
        recapNumbers = new Set()
        episodeTitleByNumber = {}
        episodeThumbnailByNumber = {}
        debugLines = []
        focusMode = false
        theatreMode = false

        try {
            details = await getAnimeDetails(Number(id))

            if (details) {
                episodeTitleByNumber = buildAniListTitleMap(details)
                void enrichTvdbEpisodeTitles(details)
            }

            if (details?.id_mal) {
                void fetchJikanFiller(details.id_mal)
            }

            pageLoading = false

            // Select and begin fetching the requested episode.
            const numbers = buildAniListEpisodeNumbers(details?.episode_count ?? null, [])
            const initialEp = numbers.includes(targetEp)
                ? targetEp
                : numbers.length > 0 ? numbers[0] : null

            if (initialEp !== null) {
                void playEpisode(initialEp)
            }
        } catch (error) {
            pageError = String(error)
            pageLoading = false
        }
    }

    async function fetchJikanFiller(malId: number) {
        try {
            const episodes = await getJikanEpisodes(malId)
            fillerNumbers = new Set(episodes.filter(e => e.filler).map(e => e.number))
            recapNumbers = new Set(episodes.filter(e => e.recap).map(e => e.number))
        } catch {
            // non-critical
        }
    }

    async function enrichTvdbEpisodeTitles(anime: AnimeDetails) {
        try {
            const tvdbEpisodes = await getTvdbEpisodes(anime.id, anime.format)
            if (details?.id !== anime.id || tvdbEpisodes.length === 0) return

            const mergedTitles = { ...episodeTitleByNumber }
            const mergedThumbs: Record<number, string | null> = { ...episodeThumbnailByNumber }
            for (const episode of tvdbEpisodes) {
                if (episode.number <= 0) continue
                const title = episode.title?.trim()
                if (title) mergedTitles[episode.number] = title
                if (episode.thumbnail) mergedThumbs[episode.number] = episode.thumbnail
            }
            episodeTitleByNumber = mergedTitles
            episodeThumbnailByNumber = mergedThumbs
        } catch {
            // best-effort
        }
    }

    async function stopActivePlayback() {
        const id = playbackSessionId
        playbackSessionId = null
        playbackProgressSeen = false
        if (!id) return
        try { await playbackStop(id) } catch { /* best-effort */ }
    }

    async function playEpisode(number: number) {
        if (!Number.isFinite(number) || number <= 0 || !details) return

        selectedEpisodeNumber = number
        sources = []
        selectedSource = null
        playbackUrl = null
        mediaError = ''
        updateEpisodeUrl(number)
        addDebugLine(`episode_select number=${number}`)

        await stopActivePlayback()

        sourcesLoading = true
        statusMessage = 'Loading episode…'

        try {
            const fetched = await getEpisodeSources(details.title, number, audioMode)
            sources = fetched

            if (sources.length === 0) {
                mediaError = 'No sources found for this episode'
                statusMessage = ''
                return
            }

            selectedSource = sources[0]
            statusMessage = 'Starting playback…'
            addDebugLine(`sources_found count=${sources.length}`)

            const result = await playbackStart(selectedSource)
            playbackUrl = result.url
            sourceKind = result.kind
            playbackSessionId = result.sessionId
            statusMessage = ''
        } catch (err) {
            mediaError = String(err)
            statusMessage = ''
            addDebugLine(`source_error ${String(err)}`)
        } finally {
            sourcesLoading = false
        }
    }

    async function handleSourceChange(source: StreamSource) {
        if (!source) return
        selectedSource = source

        const prev = playbackSessionId
        playbackSessionId = null
        if (prev) {
            try { await playbackStop(prev) } catch { /* best-effort */ }
        }

        try {
            const result = await playbackStart(source)
            playbackUrl = result.url
            sourceKind = result.kind
            playbackSessionId = result.sessionId
        } catch (err) {
            mediaError = String(err)
        }
    }

    async function handleProviderChange(value: string) {
        if ((value === 'sub' || value === 'dub') && value !== audioMode) {
            audioMode = value
            if (selectedEpisodeNumber !== null) {
                await playEpisode(selectedEpisodeNumber)
            }
        }
    }

    function updateEpisodeUrl(number: number) {
        const url = new URL(window.location.href)
        url.searchParams.set('ep', String(number))
        replaceState(url, {})
    }

    function addDebugLine(line: string) {
        const stamp = new Date().toLocaleTimeString()
        debugLines = [`${stamp} ${line}`, ...debugLines].slice(0, 6)
        logToTerminal(line, 'info')
    }

    function onPlayerPlay() {
        playbackProgressSeen = true
        if (statusMessage.toLowerCase().includes('starting')) statusMessage = ''
        mediaError = ''
    }

    function onPlayerReady() {
        playbackProgressSeen = true
        if (statusMessage.toLowerCase().includes('starting')) statusMessage = ''
    }

    // ── Breadcrumb ─────────────────────────────────────────────────────────
    $: if (details) {
        breadcrumb.items = [
            { label: 'Home', href: '/' },
            { label: details.title, href: `/anime/${details.id}` },
            { label: 'Watch' },
        ]
    }

    onDestroy(() => {
        breadcrumb.items = []
        void stopActivePlayback()
    })

    // ── Layout: sidebar height matches video height ─────────────────────────
    let sidebarHeight = 0

    function bindVideoWrap(el: HTMLDivElement) {
        const obs = new ResizeObserver(([entry]) => { sidebarHeight = entry.contentRect.height })
        obs.observe(el)
        return { destroy: () => obs.disconnect() }
    }

    $: airingDaysLeft = details?.next_airing_at
        ? Math.ceil((details.next_airing_at * 1000 - Date.now()) / 86_400_000)
        : null

    function formatAiringDate(ts: number | null): string {
        if (!ts) return ''
        return new Date(ts * 1000).toLocaleString(undefined, {
            weekday: 'short', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
        })
    }

    $: episodeMeta = (() => {
        const anilistEps = details?.episodes ?? []
        return episodeNumbers.map(n => {
            const al = anilistEps.find(e => e.number === n)
            return {
                number: n,
                title: episodeTitleByNumber[n] ?? al?.title ?? null,
                thumbnail: episodeThumbnailByNumber[n] ?? al?.thumbnail ?? null,
            }
        })
    })()
</script>

{#if pageLoading}
    <LoadingScreen label="Preparing player..." className="bg-black" />

{:else if pageError}
    <div class="min-h-screen bg-black grid place-items-center">
        <div class="text-center grid gap-3">
            <p class="text-red-400">{pageError}</p>
            <button
                class="text-sm text-white/50 hover:text-white transition-colors"
                onclick={() => goto(`/anime/${animeId}`)}
            >
                Back to anime
            </button>
        </div>
    </div>

{:else if details}
    <div class="relative min-h-screen bg-black">
        {#if focusMode}
            <button
                type="button"
                class="fixed inset-0 z-60 bg-black/75 backdrop-blur-[1px] border-0"
                aria-label="Exit focus mode"
                onclick={() => (focusMode = false)}
            ></button>
        {/if}

        <div class="mx-auto w-full max-w-400 px-3 pb-10 pt-16 sm:px-4 lg:px-6">
            <div class="grid gap-3 lg:grid-cols-[minmax(0,3fr)_minmax(0,1fr)]">

                <div class="min-w-0 {focusMode ? 'relative z-80' : ''}">
                    <div use:bindVideoWrap class="overflow-hidden rounded-xl">
                        <VideoPlayer
                            {sources}
                            {selectedSource}
                            {playbackUrl}
                            {sourceKind}
                            selectedEpisode={selectedEpisodeNumber !== null ? { anime_id: String(animeId), number: String(selectedEpisodeNumber), source_id: null } : null}
                            {episodeNumbers}
                            {selectedNumber}
                            episodeTitle={selectedEpisodeTitle}
                            {autoPlay}
                            {autoNext}
                            {focusMode}
                            {theatreMode}
                            animeTitle={details.title}
                            provider={audioMode}
                            providerOptions={PROVIDER_OPTIONS}
                            loading={sourcesLoading}
                            {statusMessage}
                            {mediaError}
                            onSourceChange={handleSourceChange}
                            onProviderChange={handleProviderChange}
                            onToggleAutoPlay={() => autoPlay = !autoPlay}
                            onToggleAutoNext={() => autoNext = !autoNext}
                            onToggleFocus={() => focusMode = !focusMode}
                            onToggleTheatre={() => theatreMode = !theatreMode}
                            onEpisodeSelect={playEpisode}
                            onPlay={onPlayerPlay}
                            onReady={onPlayerReady}
                            onStartupError={() => {}}
                            onFatalHls={() => {}}
                            onMediaError={() => {}}
                            onHlsInfo={() => {}}
                        />
                    </div>
                </div>

                <!-- Episode sidebar (desktop) -->
                <aside
                    class="hidden lg:flex flex-col overflow-hidden rounded-xl pt-3 pb-2 bg-white/3 border border-white/6"
                    style="{sidebarHeight > 0 ? `max-height:${sidebarHeight}px;` : ''}"
                >
                    <EpisodeSidebar
                        episodes={episodeMeta}
                        {episodeNumbers}
                        {fillerNumbers}
                        {recapNumbers}
                        {selectedNumber}
                        animeTitle={details.title}
                        episodeTitle={selectedEpisodeTitle}
                        loading={pageLoading && episodeNumbers.length === 0}
                        onSelect={playEpisode}
                    />
                </aside>

                <div class="flex flex-col gap-4 min-w-0">
                    <!-- Mobile sidebar -->
                    <div class="lg:hidden overflow-hidden rounded-xl pt-3 pb-2 bg-white/3 border border-white/6" style="max-height:50vh;">
                        <EpisodeSidebar
                            episodes={episodeMeta}
                            {episodeNumbers}
                            {fillerNumbers}
                            {recapNumbers}
                            {selectedNumber}
                            animeTitle={details.title}
                            episodeTitle={selectedEpisodeTitle}
                            loading={pageLoading && episodeNumbers.length === 0}
                            onSelect={playEpisode}
                        />
                    </div>

                    {#if airingDaysLeft !== null && airingDaysLeft > 0}
                        <div class="relative group flex items-center gap-2.5 px-4 py-3 rounded-xl
                                    bg-emerald-950/60 border border-emerald-700/50 text-sm text-white/90
                                    cursor-default select-none">
                            <BellSimpleRingingIcon size={16} class="text-emerald-400 shrink-0" weight="fill" />
                            <span>
                                {#if details.next_airing_episode}Episode {details.next_airing_episode} airs in{:else}Next episode airs in{/if}
                                <span class="text-emerald-400 font-semibold">{airingDaysLeft} {airingDaysLeft === 1 ? 'day' : 'days'}</span>
                            </span>
                            {#if details.next_airing_at}
                                <div class="absolute bottom-full left-0 mb-2 px-3 py-2 rounded-xl border border-white/12 bg-[#111] shadow-xl
                                            text-[0.72rem] text-white/70 whitespace-nowrap z-50
                                            opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity duration-150">
                                    {formatAiringDate(details.next_airing_at)}
                                </div>
                            {/if}
                        </div>
                    {/if}

                    <EpisodeInfo
                        anime={details}
                        episodeNumber={selectedNumber}
                        episodeTitle={selectedEpisodeTitle}
                        providerOptions={PROVIDER_OPTIONS}
                        provider={audioMode}
                        onProviderChange={handleProviderChange}
                    />
                </div>

                {#if details.recommendations?.length}
                    <div class="hidden lg:block">
                        <h3 class="text-[18px] font-semibold text-white mb-3 px-0.5 py-1">More Like This</h3>
                        <div class="space-y-2">
                            {#each details.recommendations.slice(0, 12) as rec (rec.id)}
                                <RecommendationCard {rec} />
                            {/each}
                        </div>
                    </div>
                {:else}
                    <div class="hidden lg:block"></div>
                {/if}

            </div>
        </div>
    </div>
{/if}
