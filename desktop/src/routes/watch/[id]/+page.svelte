<script lang="ts">
    import { page } from '$app/stores'
    import { goto, replaceState } from '$app/navigation'
    import { onDestroy } from 'svelte'
    import VideoPlayer from '$lib/components/player/VideoPlayer.svelte'
    import EpisodeGrid from '$lib/components/player/EpisodeGrid.svelte'
    import LoadingScreen from '$lib/components/shared/LoadingScreen.svelte'
    import { getAnimeDetails } from '$lib/api/anime'
    import { getJikanEpisodes } from '$lib/api/jikan'
    import { logToTerminal } from '$lib/api/logging'
    import { getTvdbEpisodes } from '$lib/api/tvdb'
    import { playbackStart, playbackStop } from '$lib/api/playback'
    import { streamSearch, streamEpisodes, streamSources } from '$lib/api/stream'
    import type { AnimeDetails } from '$lib/types/anime'
    import type { StreamableAnime, StreamingEpisode, StreamSource, ProviderKind } from '$lib/types/stream'
    import {
        buildAniListEpisodeNumbers,
        buildAniListTitleMap,
        episodeTitleForNumber as resolveEpisodeTitleForNumber,
        parseEpisodeNumber,
        parseRequestedEpisode,
        resolveEpisodeByNumber,
        syntheticEpisode,
        type EpisodeMatchKind,
    } from '$lib/utils/watch/episodes'
    import { buildSearchQueries as buildWatchSearchQueries, inferExplicitSeasonIndex } from '$lib/utils/watch/search'
    import {
        rankProviderMatches as rankProviderMatchesUtil,
        scoreEpisodeMappingConfidence,
        validateCandidateMapping,
        type WatchMatchContext,
    } from '$lib/utils/watch/matching'
    import {
        buildPlaybackFailureMessage as buildPlaybackFailureMessageUtil,
        formatSourceLabel,
        orderSources,
        providerName as resolveProviderName,
    } from '$lib/utils/watch/provider'

    const PROVIDER_OPTIONS: { label: string; value: ProviderKind }[] = [
        { label: 'AllAnime', value: 'allanime' },
        { label: 'AnimePahe', value: 'animepahe' },
        { label: 'Anizone', value: 'anizone' },
        { label: 'Anidap', value: 'anidap' },
    ]
    type ProviderContext = { streamAnime: StreamableAnime; episodes: StreamingEpisode[] }

    let details: AnimeDetails | null = null
    let pageLoading = true
    let pageError: string | null = null

    let provider: ProviderKind = 'animepahe'
    let streamAnime: StreamableAnime | null = null
    let streamAnimeProvider: ProviderKind | null = null
    let providerContexts = new Map<ProviderKind, ProviderContext>()
    let episodes: StreamingEpisode[] = []
    let selectedEpisode: StreamingEpisode | null = null

    let sources: StreamSource[] = []
    let selectedSource: StreamSource | null = null
    let playbackUrl: string | null = null
    let sourceKind: string = 'hls'
    let playbackSessionId: string | null = null

    let bootstrapping = false
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
    let tvdbEpisodeOffset: number | null = null

    $: animeId = $page.params.id
    $: requestedEp = parseRequestedEpisode($page.url.searchParams.get('ep'))
    $: episodeNumbers = buildAniListEpisodeNumbers(details?.episode_count ?? null, episodes)
    $: selectedNumber = (() => {
        const parsed = parseEpisodeNumber(selectedEpisode?.number)
        return Number.isFinite(parsed) && parsed > 0 ? parsed : requestedEp
    })()
    $: selectedEpisodeTitle = (() => {
        if (!selectedEpisode) return 'Select Episode'
        const parsed = parseEpisodeNumber(selectedEpisode.number)
        if (Number.isFinite(parsed) && parsed > 0) {
            return episodeTitleForNumber(parsed)
        }
        return `Episode ${selectedEpisode.number}`
    })()

    $: if (animeId) bootstrap(animeId, requestedEp)

    function providerName(value: ProviderKind): string {
        return resolveProviderName(value, PROVIDER_OPTIONS)
    }

    function buildPlaybackFailureMessage(stage: string, reason: string): string {
        return buildPlaybackFailureMessageUtil({
            stage,
            reason,
            provider,
            providerOptions: PROVIDER_OPTIONS,
            selectedNumber,
            selectedSource,
        })
    }

    function buildSearchQueries(base: string, targetProvider: ProviderKind): string[] {
        const relationTitles = (details?.relations ?? [])
            .map(relation => relation.title?.trim() ?? '')
            .filter(Boolean)
            .slice(0, 4)
        return buildWatchSearchQueries(base, targetProvider, {
            detailsTitle: details?.title ?? '',
            detailsTitleJapanese: details?.title_japanese ?? '',
            relationTitles,
        })
    }

    function watchMatchContext(): WatchMatchContext {
        return {
            title: details?.title ?? '',
            titleJapanese: details?.title_japanese ?? '',
            episodeCount: details?.episode_count ?? null,
            seasonYear: details?.season_year ?? null,
            season: details?.season ?? null,
            status: details?.status ?? null,
            format: details?.format ?? null,
        }
    }

    function rankProviderMatches(
        results: StreamableAnime[],
        hint: string,
        desiredEpisode?: number,
        targetProvider: ProviderKind = provider,
    ): Array<{ anime: StreamableAnime; score: number }> {
        return rankProviderMatchesUtil(results, hint, desiredEpisode, targetProvider, watchMatchContext())
    }

    function episodeTitleForNumber(number: number): string {
        return resolveEpisodeTitleForNumber(episodeTitleByNumber, number)
    }

    async function bootstrap(id: string, targetEp: number) {
        pageLoading = true
        pageError = null
        mediaError = ''
        statusMessage = ''

        await stopActivePlayback()

        streamAnime = null
        streamAnimeProvider = null
        providerContexts = new Map()
        episodes = []
        selectedEpisode = null
        sources = []
        selectedSource = null
        playbackUrl = null
        sourceKind = 'hls'
        fillerNumbers = new Set()
        recapNumbers = new Set()
        episodeTitleByNumber = {}
        tvdbEpisodeOffset = null
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

            // Render the page shell as soon as metadata is available.
            pageLoading = false
            await bootstrapProvider(details?.title ?? '', targetEp)
        } catch (error) {
            pageError = String(error)
            pageLoading = false
        } finally {
            if (pageError) pageLoading = false
        }
    }

    async function fetchJikanFiller(malId: number) {
        try {
            const episodes = await getJikanEpisodes(malId)
            fillerNumbers = new Set(episodes.filter(episode => episode.filler).map(episode => episode.number))
            recapNumbers = new Set(episodes.filter(episode => episode.recap).map(episode => episode.number))
        } catch {
            // filler data is non-critical
        }
    }

    async function enrichTvdbEpisodeTitles(anime: AnimeDetails) {
        try {
            const tvdbEpisodes = await getTvdbEpisodes(anime.id, anime.format)
            if (details?.id !== anime.id || tvdbEpisodes.length === 0) return

            const merged = { ...episodeTitleByNumber }
            for (const episode of tvdbEpisodes) {
                const title = episode.title?.trim()
                if (!title || episode.number <= 0) continue
                merged[episode.number] = title
            }
            episodeTitleByNumber = merged

            const numbered = tvdbEpisodes
                .map(episode => episode.number)
                .filter(number => Number.isFinite(number) && number > 0)
                .sort((a, b) => a - b)
            if (numbered.length > 0) {
                const minNumber = numbered[0]
                const maxNumber = numbered[numbered.length - 1]
                tvdbEpisodeOffset = minNumber > 1 ? minNumber - 1 : null
                addDebugLine(
                    `tvdb_episode_window min=${minNumber} max=${maxNumber} offset=${tvdbEpisodeOffset ?? 0} count=${numbered.length}`,
                )
            }
        } catch {
            // title enrichment is best-effort
        }
    }

    async function bootstrapProvider(titleHint: string, targetEp: number) {
        bootstrapping = true
        mediaError = ''

        try {
            const numbers = buildAniListEpisodeNumbers(details?.episode_count ?? null, [])
            const initialEp = numbers.includes(targetEp)
                ? targetEp
                : (numbers[0] ?? targetEp)

            await selectAndPlay(initialEp, titleHint)
        } catch (error) {
            mediaError = String(error)
            statusMessage = ''
        } finally {
            bootstrapping = false
        }
    }

    async function switchProvider(next: ProviderKind) {
        if (provider === next && streamAnimeProvider === next) return
        provider = next
        if (!details) return

        await stopActivePlayback()
        playbackUrl = null
        selectedSource = null
        sources = []
        sourceKind = 'hls'
        statusMessage = `Switching to ${providerName(next)}...`
        mediaError = ''
        addDebugLine(`provider_switch provider=${providerName(next)} episode=${selectedNumber}`)

        const currentEp = selectedNumber
        await selectAndPlay(currentEp, details.title, next)
    }

    async function stopActivePlayback() {
        const currentSessionId = playbackSessionId
        playbackSessionId = null
        playbackProgressSeen = false

        if (!currentSessionId) return

        try {
            await playbackStop(currentSessionId)
        } catch {
            // session teardown is best-effort
        }
    }

    async function startPlaybackForSource(source: StreamSource, episodeNumber: number = selectedNumber) {
        await stopActivePlayback()
        playbackProgressSeen = false

        const started = await playbackStart(source)
        selectedSource = source
        sourceKind = started.kind
        playbackUrl = started.url
        playbackSessionId = started.sessionId
        addDebugLine(
            `playback_start provider=${providerName(provider)} episode=${episodeNumber} source=${formatSourceLabel(source)} kind=${started.kind}`,
        )
    }

    async function selectAndPlay(number: number, titleHint: string, forcedProvider?: ProviderKind) {
        if (!Number.isFinite(number) || number <= 0) return

        sourcesLoading = true
        mediaError = ''
        statusMessage = ''

        try {
            const targetProvider = forcedProvider ?? provider
            const context = await resolveProviderContext(targetProvider, titleHint, number)
            if (!context) {
                const errorMessage = `No stream result found in ${providerName(targetProvider)} for "${titleHint}".`
                mediaError = errorMessage
                statusMessage = ''
                addDebugLine(
                    `stream_lookup_failed provider=${providerName(targetProvider)} episode=${number} error=${errorMessage}`,
                )
                return
            }

            const desiredSeasonIndex = inferExplicitSeasonIndex(
                titleHint,
                details?.title ?? '',
                details?.title_japanese ?? '',
            )
            const episodeMatch = resolveEpisodeByNumber(
                context.episodes,
                number,
                {
                    requireSourceId: targetProvider === 'animepahe',
                    expectedEpisodeCount:
                        details?.episode_count ?? context.streamAnime.available_episodes ?? null,
                    seasonIndex: Number.isFinite(Number(desiredSeasonIndex)) ? Number(desiredSeasonIndex) : null,
                    tvdbOffset: tvdbEpisodeOffset,
                },
            )
            const matchValidation = validateCandidateMapping(
                targetProvider,
                context.streamAnime,
                episodeMatch,
                Number.isFinite(Number(details?.episode_count)) ? Number(details?.episode_count) : Number.NaN,
                Number.isFinite(Number(desiredSeasonIndex)) ? Number(desiredSeasonIndex) : Number.NaN,
                Number.isFinite(Number(details?.season_year)) ? Number(details?.season_year) : Number.NaN,
            )
            const matchedEpisode = episodeMatch.episode
            const candidateEpisode = matchedEpisode ?? syntheticEpisode(number, context.streamAnime.id)
            const resolvedEpisode: StreamingEpisode = {
                anime_id: context.streamAnime.id,
                number: String(number),
                source_id: candidateEpisode.source_id,
            }
            addDebugLine(
                `episode_match provider=${providerName(targetProvider)} requested=${number} mapped_to=${matchedEpisode?.number ?? 'none'} kind=${episodeMatch.kind} min=${Number.isFinite(episodeMatch.minNumber) ? episodeMatch.minNumber : 'na'} max=${Number.isFinite(episodeMatch.maxNumber) ? episodeMatch.maxNumber : 'na'}`,
            )
            if (!matchValidation.accepted) {
                const errorMessage = `Episode mapping for ${providerName(targetProvider)} was rejected: ${matchValidation.reason}.`
                mediaError = errorMessage
                statusMessage = ''
                addDebugLine(
                    `episode_mapping_rejected provider=${providerName(targetProvider)} requested=${number} map=${episodeMatch.kind}:${matchedEpisode?.number ?? 'none'} reason=${matchValidation.reason}`,
                )
                return
            }
            if (targetProvider === 'animepahe' && !candidateEpisode.source_id) {
                const errorMessage = `AnimePahe episode mapping failed for episode ${number}. No episode session ID was found.`
                mediaError = errorMessage
                statusMessage = ''
                addDebugLine(
                    `episode_mapping_failed provider=${providerName(targetProvider)} requested=${number} matched=${matchedEpisode?.number ?? 'none'} source_id=${candidateEpisode.source_id ?? 'none'}`,
                )
                return
            }

            statusMessage = `Loading sources for EP ${number} from ${providerName(targetProvider)}...`
            const providerSources = await streamSources(targetProvider, candidateEpisode, null)
            addDebugLine(
                `source_candidates provider=${providerName(targetProvider)} episode=${number} list=${providerSources
                    .map(source => formatSourceLabel(source))
                    .join(',') || 'none'}`,
            )
            const orderedSources = orderSources(providerSources)

            if (orderedSources.length === 0) {
                const errorMessage = `No sources found for episode ${number} on ${providerName(targetProvider)}.`
                mediaError = errorMessage
                statusMessage = ''
                addDebugLine(
                    `source_lookup_failed provider=${providerName(targetProvider)} episode=${number} error=${errorMessage}`,
                )
                return
            }

            const source = orderedSources[0]
            provider = targetProvider
            streamAnime = context.streamAnime
            streamAnimeProvider = targetProvider
            episodes = context.episodes
            selectedEpisode = resolvedEpisode
            sources = providerSources
            await startPlaybackForSource(source, number)
            mediaError = ''
            statusMessage = autoPlay ? 'Starting playback...' : 'Ready. Press play to start.'
            addDebugLine(
                `source_selected provider=${providerName(targetProvider)} episode=${number} source=${formatSourceLabel(source)}`,
            )
            updateEpisodeUrl(number)
        } catch (error) {
            const errorMessage = String(error)
            mediaError = buildPlaybackFailureMessage('select_and_play', errorMessage)
            statusMessage = ''
            addDebugLine(
                `select_and_play_failed provider=${providerName(forcedProvider ?? provider)} episode=${number} error=${errorMessage}`,
            )
            await stopActivePlayback()
            playbackUrl = null
            selectedSource = null
        } finally {
            sourcesLoading = false
        }
    }

    async function playEpisode(number: number) {
        addDebugLine(`episode_change requested=${number} stopping_current_playback`)
        mediaError = ''
        playbackUrl = null
        selectedSource = null
        sources = []
        await stopActivePlayback()
        statusMessage = `Loading episode ${number}...`
        await selectAndPlay(number, details?.title ?? '')
    }

    async function onSourceChange(src: StreamSource) {
        if (!details || !selectedEpisode) return

        try {
            await startPlaybackForSource(src)
            mediaError = ''
            statusMessage = autoPlay ? 'Starting playback...' : 'Ready. Press play to start.'
            addDebugLine(
                `source_changed provider=${providerName(provider)} episode=${selectedNumber} source=${formatSourceLabel(src)}`,
            )
        } catch (error) {
            const errorMessage = String(error)
            mediaError = buildPlaybackFailureMessage('source_change', errorMessage)
            statusMessage = ''
            addDebugLine(
                `source_change_failed provider=${providerName(provider)} episode=${selectedNumber} source=${formatSourceLabel(src)} error=${errorMessage}`,
            )
        }
    }

    function onPlayerStartupError(event: CustomEvent<{ message?: string }>) {
        const reason = event.detail?.message ?? 'Playback startup failed.'
        mediaError = buildPlaybackFailureMessage('startup_error', reason)
        statusMessage = ''
        addDebugLine(
            `startup_error provider=${providerName(provider)} episode=${selectedNumber} source=${formatSourceLabel(selectedSource)} error=${reason}`,
        )
    }

    function onPlayerFatalHls(event: CustomEvent<{ message?: string }>) {
        const reason = event.detail?.message ?? 'Fatal HLS playback error.'
        const normalizedReason = reason.toLowerCase()
        if (playbackProgressSeen && normalizedReason.includes('bufferaddcodecerror')) {
            addDebugLine(
                `fatal_hls_ignored provider=${providerName(provider)} episode=${selectedNumber} source=${formatSourceLabel(selectedSource)} reason=${reason}`,
            )
            return
        }
        mediaError = buildPlaybackFailureMessage('fatal_hls', reason)
        statusMessage = ''
        addDebugLine(
            `fatal_hls provider=${providerName(provider)} episode=${selectedNumber} source=${formatSourceLabel(selectedSource)} error=${reason}`,
        )
    }

    function onPlayerMediaError(event: CustomEvent<{ message?: string }>) {
        const reason = event.detail?.message ?? 'Media playback error.'
        mediaError = buildPlaybackFailureMessage('media_error', reason)
        statusMessage = ''
        addDebugLine(
            `media_error provider=${providerName(provider)} episode=${selectedNumber} source=${formatSourceLabel(selectedSource)} error=${reason}`,
        )
    }

    function onHlsInfo(event: CustomEvent<{ message?: string }>) {
        const message = event.detail?.message ?? 'hls event'
        const normalizedMessage = message.toLowerCase()
        if (normalizedMessage.includes('frag_loaded')) {
            playbackProgressSeen = true
        }
        addDebugLine(message)
    }

    async function resolveProviderContext(
        targetProvider: ProviderKind,
        titleHint: string,
        desiredEpisode: number,
    ): Promise<ProviderContext | null> {
        const cached = providerContexts.get(targetProvider)
        if (cached) {
            return cached
        }

        if (targetProvider === streamAnimeProvider && streamAnime) {
            return {
                streamAnime,
                episodes,
            }
        }

        const desiredSeasonIndex = inferExplicitSeasonIndex(
            titleHint,
            details?.title ?? '',
            details?.title_japanese ?? '',
        )
        const expectedEpisodeCount = Number(details?.episode_count)
        const desiredYear = Number(details?.season_year)
        let bestCandidate:
            | (ProviderContext & {
                query: string
                titleScore: number
                mappingScore: number
                validationAdjustment: number
                totalScore: number
                mappingKind: EpisodeMatchKind
                mappedNumber: string | null
            })
            | null = null

        statusMessage = `Searching ${providerName(targetProvider)}...`
        for (const query of buildSearchQueries(titleHint, targetProvider)) {
            const results = await streamSearch(targetProvider, query)
            const rankedCandidates = rankProviderMatches(results, titleHint, desiredEpisode, targetProvider).slice(
                0,
                targetProvider === 'animepahe' ? 6 : 4,
            )
            if (rankedCandidates.length === 0) continue

            for (const candidate of rankedCandidates) {
                const providerEpisodes = await streamEpisodes(targetProvider, candidate.anime)
                if (providerEpisodes.length === 0) {
                    addDebugLine(
                        `episode_list_empty provider=${providerName(targetProvider)} query=${query} matched=${candidate.anime.title}`,
                    )
                    continue
                }

                const match = resolveEpisodeByNumber(providerEpisodes, desiredEpisode, {
                    requireSourceId: targetProvider === 'animepahe',
                    expectedEpisodeCount: Number.isFinite(expectedEpisodeCount) ? expectedEpisodeCount : null,
                    seasonIndex: Number.isFinite(desiredSeasonIndex) ? desiredSeasonIndex : null,
                    tvdbOffset: tvdbEpisodeOffset,
                })
                const mappingScore = scoreEpisodeMappingConfidence(
                    match,
                    Number.isFinite(expectedEpisodeCount) ? expectedEpisodeCount : Number.NaN,
                    Number.isFinite(Number(desiredSeasonIndex)) ? Number(desiredSeasonIndex) : Number.NaN,
                )
                const validation = validateCandidateMapping(
                    targetProvider,
                    candidate.anime,
                    match,
                    Number.isFinite(expectedEpisodeCount) ? expectedEpisodeCount : Number.NaN,
                    Number.isFinite(Number(desiredSeasonIndex)) ? Number(desiredSeasonIndex) : Number.NaN,
                    Number.isFinite(desiredYear) ? desiredYear : Number.NaN,
                )
                if (!validation.accepted) {
                    addDebugLine(
                        `candidate_rejected provider=${providerName(targetProvider)} query=${query} title=${candidate.anime.title} map=${match.kind}:${match.episode?.number ?? 'none'} reason=${validation.reason}`,
                    )
                    continue
                }

                const totalScore = candidate.score + mappingScore + validation.adjustment

                addDebugLine(
                    `candidate_eval provider=${providerName(targetProvider)} query=${query} title=${candidate.anime.title} year=${candidate.anime.year ?? 'na'} title_score=${candidate.score.toFixed(1)} map=${match.kind}:${match.episode?.number ?? 'none'} map_score=${mappingScore.toFixed(1)} gate=${validation.adjustment.toFixed(1)} total=${totalScore.toFixed(1)}`,
                )

                if (!bestCandidate || totalScore > bestCandidate.totalScore) {
                    bestCandidate = {
                        streamAnime: candidate.anime,
                        episodes: providerEpisodes,
                        query,
                        titleScore: candidate.score,
                        mappingScore,
                        validationAdjustment: validation.adjustment,
                        totalScore,
                        mappingKind: match.kind,
                        mappedNumber: match.episode?.number ?? null,
                    }
                }
            }

            if (bestCandidate && bestCandidate.totalScore >= 430 && bestCandidate.mappingScore >= 170) break
        }

        if (!bestCandidate) return null

        const context: ProviderContext = {
            streamAnime: bestCandidate.streamAnime,
            episodes: bestCandidate.episodes,
        }
        providerContexts.set(targetProvider, context)
        addDebugLine(
            `provider_match_selected provider=${providerName(targetProvider)} title=${bestCandidate.streamAnime.title} query=${bestCandidate.query} title_score=${bestCandidate.titleScore.toFixed(1)} map=${bestCandidate.mappingKind}:${bestCandidate.mappedNumber ?? 'none'} gate=${bestCandidate.validationAdjustment.toFixed(1)} total=${bestCandidate.totalScore.toFixed(1)}`,
        )
        return context
    }

    function addDebugLine(line: string) {
        const stamp = new Date().toLocaleTimeString()
        debugLines = [`${stamp} ${line}`, ...debugLines].slice(0, 6)
        const normalized = line.toLowerCase()
        const level = normalized.includes('error') || normalized.includes('failed') ? 'error' : 'info'
        logToTerminal(line, level)
    }

    function updateEpisodeUrl(number: number) {
        const url = new URL(window.location.href)
        url.searchParams.set('ep', String(number))
        replaceState(url, {})
    }

    onDestroy(() => {
        void stopActivePlayback()
    })

    function onPlayerPlay() {
        playbackProgressSeen = true
        if (statusMessage.toLowerCase().includes('starting playback')) {
            statusMessage = ''
        }
        mediaError = ''
    }

    function onPlayerReady() {
        playbackProgressSeen = true
        if (statusMessage.toLowerCase().includes('starting playback')) {
            statusMessage = ''
        }
    }
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
            class="fixed inset-0 z-[60] bg-black/75 backdrop-blur-[1px] border-0"
            aria-label="Exit focus mode"
            onclick={() => (focusMode = false)}
        ></button>
        {/if}

        <div class="mx-auto w-full max-w-[1740px] px-3 pb-6 pt-16 sm:px-4 lg:px-6">
            <div class="grid gap-4 {theatreMode ? 'xl:h-auto xl:grid-cols-1' : 'lg:grid-cols-[minmax(0,8fr)_minmax(0,2fr)] xl:h-[calc(100vh-5.25rem)]'}">
                <section
                    class="flex min-h-0 flex-col rounded-xl p-2 sm:p-3
                           {theatreMode ? 'mx-auto w-full max-w-[1240px]' : ''}
                           {focusMode ? 'relative z-[80]' : ''}"
                >

                <VideoPlayer
                    {sources}
                    {selectedSource}
                    {playbackUrl}
                    {sourceKind}
                    {selectedEpisode}
                    {episodeNumbers}
                    {selectedNumber}
                    episodeTitle={selectedEpisodeTitle}
                    {autoPlay}
                    {autoNext}
                    {focusMode}
                    {theatreMode}
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
                    on:toggleTheatre={() => theatreMode = !theatreMode}
                    on:episodeSelect={e => playEpisode(e.detail)}
                    on:play={onPlayerPlay}
                    on:ready={onPlayerReady}
                    on:startup_error={onPlayerStartupError}
                    on:fatal_hls={onPlayerFatalHls}
                    on:media_error={onPlayerMediaError}
                    on:hls_info={onHlsInfo}
                />
                </section>

                <aside class="flex min-h-0 flex-col rounded-xl p-2 sm:p-3">
                    <div class="mb-2 flex items-center justify-between px-1">
                        <h2 class="text-sm font-medium text-white">Episodes</h2>
                        <span class="text-xs text-white/45">{episodeNumbers.length}</span>
                    </div>
                    <EpisodeGrid
                        {episodeNumbers}
                        {fillerNumbers}
                        {recapNumbers}
                        {selectedNumber}
                        loading={bootstrapping && episodeNumbers.length === 0}
                        on:select={e => playEpisode(e.detail)}
                    />
                </aside>

            </div>
        </div>
    </div>
{/if}