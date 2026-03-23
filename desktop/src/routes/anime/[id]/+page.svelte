<script lang="ts">
  import { page } from '$app/stores'
  import { getAnimeDetails } from '$lib/api/anime'
  import type { AnimeDetails } from '$lib/types/anime'
  import { getTvdbEpisodes } from '$lib/api/tvdb'
  import { getJikanEpisodes, getJikanEpisodesPage } from '$lib/api/jikan'
  import type { TvdbEpisode } from '$lib/types/tvdb'
  import type { JikanEpisode, JikanEpisodesPage } from '$lib/types/jikan'
  import type { Episode } from '$lib/types/anime'
  import AnimeRow from '$lib/components/AnimeRow.svelte'
  import { PlayIcon, HeartIcon } from 'phosphor-svelte'
  import EpisodeList from '$lib/components/EpisodeList.svelte'
  import CharactersRow from '$lib/components/CharectersRow.svelte'
  import LoadingScreen from '$lib/components/shared/LoadingScreen.svelte'

  const INITIAL_ENRICH_WAIT_MS = 900
  const JIKAN_BATCH_SIZE = 25

  let details: AnimeDetails | null = null
  let loading = true
  let error: string | null = null
  let loadVersion = 0
  let hasAnilistEpisodeBase = false
  let fallbackEpisodeCount: number | null = null
  let jikanNextPage = 1
  let jikanHasMore = false
  let jikanApiHasMore = false
  let jikanPaging = false
  let jikanBufferedEpisodes: JikanEpisode[] = []

  $: id = Number($page.params.id)

  $: if (id) {
    void loadDetails(id)
  }

  $: resolvedEpisodeCount = (() => {
    const candidates = [
      details?.episode_count ?? null,
      fallbackEpisodeCount,
      details?.episodes.length ?? null,
    ]
      .map(value => (Number.isFinite(Number(value)) ? Number(value) : 0))
      .filter(value => value > 0)

    if (candidates.length === 0) return null
    return Math.max(...candidates)
  })()

  function delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  function applyEnrichedEpisodes(
    current: AnimeDetails,
    sourceEpisodes: TvdbEpisode[] | JikanEpisode[],
    source: 'tvdb' | 'jikan',
    appendMissing: boolean = true
  ): AnimeDetails {
    const sourceAsEpisodes: Episode[] = source === 'tvdb'
      ? (sourceEpisodes as TvdbEpisode[])
          .filter(ep => Number.isFinite(ep.number) && ep.number > 0)
          .map(ep => ({
            number: ep.number,
            title: ep.title ?? null,
            thumbnail: ep.thumbnail ?? null,
            description: null,
          }))
      : (sourceEpisodes as JikanEpisode[])
          .filter(ep => Number.isFinite(ep.number) && ep.number > 0)
          .map(ep => ({
            number: ep.number,
            title: ep.title ?? null,
            thumbnail: null,
            description: null,
          }))

    const baseEpisodes = current.episodes.length
      ? current.episodes
      : appendMissing
        ? sourceAsEpisodes.sort((a, b) => a.number - b.number)
        : []

    const merged = new Map<number, Episode>()
    for (const ep of baseEpisodes) {
      merged.set(ep.number, ep)
    }
    for (const ep of sourceAsEpisodes) {
      const existing = merged.get(ep.number)
      if (!existing) {
        if (!appendMissing) continue
        merged.set(ep.number, ep)
        continue
      }
      merged.set(ep.number, {
        ...existing,
        title: ep.title ?? existing.title,
        thumbnail: ep.thumbnail ?? existing.thumbnail,
      })
    }

    const mergedEpisodes = Array.from(merged.values()).sort((a, b) => a.number - b.number)

    return {
      ...current,
      episodes: mergedEpisodes.map(ep => {
        if (source === 'tvdb') {
          const match = (sourceEpisodes as TvdbEpisode[]).find(t => t.number === Number(ep.number))
          if (!match) return ep
          return {
            ...ep,
            title: match.title ?? ep.title,
            thumbnail: match.thumbnail ?? ep.thumbnail,
          }
        }

        const match = (sourceEpisodes as JikanEpisode[]).find(j => j.number === Number(ep.number))
        if (!match) return ep
        return {
          ...ep,
          title: match.title ?? ep.title,
        }
      })
    }
  }

  async function loadDetails(animeId: number) {
    const requestVersion = ++loadVersion
    loading = true
    error = null
    details = null
    hasAnilistEpisodeBase = false
    fallbackEpisodeCount = null
    jikanNextPage = 1
    jikanHasMore = false
    jikanApiHasMore = false
    jikanPaging = false
    jikanBufferedEpisodes = []

    console.log('[TVDB][ui] loading anime details', { id: animeId, requestVersion })

    try {
      const d = await getAnimeDetails(animeId)
      if (requestVersion !== loadVersion) return

      console.log('[TVDB][ui] anime details loaded', {
        id: d.id,
        format: d.format,
        id_mal: d.id_mal,
        episodeCount: d.episodes?.length ?? 0,
      })

      details = d
      hasAnilistEpisodeBase = d.episodes.length > 0

      const enrichmentTask = enrichEpisodes(d, requestVersion)

      // Give enrichment a short head-start while keeping the loading view visible.
      await Promise.race([
        enrichmentTask,
        delay(INITIAL_ENRICH_WAIT_MS),
      ])
    } catch (e) {
      if (requestVersion !== loadVersion) return
      console.error('[TVDB][ui] getAnimeDetails failed', e)
      error = String(e)
    } finally {
      if (requestVersion === loadVersion) {
        loading = false
      }
    }
  }

  async function fetchJikanPage(malId: number, page: number): Promise<JikanEpisodesPage> {
    return getJikanEpisodesPage(malId, page)
  }

  async function seedJikanBaseEpisodes(malId: number, animeId: number, requestVersion: number): Promise<boolean> {
    const paged = await fetchJikanPage(malId, 1)
    if (requestVersion !== loadVersion || details?.id !== animeId) return false

    console.log('[TVDB][ui] jikan base paged response', {
      malId,
      page: paged.page,
      episodes: paged.episodes.length,
      hasNextPage: paged.has_next_page,
      totalEpisodes: paged.total_episodes ?? null,
    })

    if (Number.isFinite(paged.total_episodes ?? null) && Number(paged.total_episodes) > 0) {
      fallbackEpisodeCount = Math.max(fallbackEpisodeCount ?? 0, Number(paged.total_episodes))
    }

    const firstChunk = paged.episodes.slice(0, JIKAN_BATCH_SIZE)
    jikanBufferedEpisodes = paged.episodes.slice(firstChunk.length)

    if (firstChunk.length && details) {
      details = applyEnrichedEpisodes(details, firstChunk, 'jikan', true)
    }
    jikanApiHasMore = paged.has_next_page
    jikanHasMore = jikanApiHasMore || jikanBufferedEpisodes.length > 0
    jikanNextPage = jikanApiHasMore ? paged.page + 1 : paged.page
    return firstChunk.length > 0
  }

  function applyJikanChunk(chunk: JikanEpisode[]) {
    if (!details || chunk.length === 0) return
    details = applyEnrichedEpisodes(details, chunk, 'jikan', !hasAnilistEpisodeBase)
  }

  async function fetchAndApplyNextJikanPage(malId: number, requestVersion: number): Promise<boolean> {
    const paged = await fetchJikanPage(malId, jikanNextPage)
    if (requestVersion !== loadVersion || !details) return false

    if (Number.isFinite(paged.total_episodes ?? null) && Number(paged.total_episodes) > 0) {
      fallbackEpisodeCount = Math.max(fallbackEpisodeCount ?? 0, Number(paged.total_episodes))
    }

    const chunk = paged.episodes.slice(0, JIKAN_BATCH_SIZE)
    const remainder = paged.episodes.slice(chunk.length)
    applyJikanChunk(chunk)

    jikanBufferedEpisodes = remainder
    jikanApiHasMore = paged.has_next_page
    jikanHasMore = jikanApiHasMore || jikanBufferedEpisodes.length > 0
    jikanNextPage = jikanApiHasMore ? paged.page + 1 : paged.page
    return chunk.length > 0 || remainder.length > 0
  }

  async function onEpisodeListLoadMore(requiredCountArg: number = 0) {
    if (!details?.id_mal || !jikanHasMore || jikanPaging) return
    jikanPaging = true
    const requestVersion = loadVersion
    const requiredCount = Math.max(0, requiredCountArg)
    const currentCount = details.episodes.length
    const targetCount = Math.max(requiredCount, currentCount + 1)

    try {
      while (details && details.episodes.length < targetCount) {
        if (jikanBufferedEpisodes.length > 0) {
          const remainingNeeded = targetCount - details.episodes.length
          const takeCount = Math.max(
            1,
            Math.min(JIKAN_BATCH_SIZE, jikanBufferedEpisodes.length, remainingNeeded)
          )
          const chunk = jikanBufferedEpisodes.slice(0, takeCount)
          jikanBufferedEpisodes = jikanBufferedEpisodes.slice(takeCount)
          applyJikanChunk(chunk)
          jikanHasMore = jikanApiHasMore || jikanBufferedEpisodes.length > 0
          if (chunk.length === 0) break
          continue
        }

        if (!jikanApiHasMore) {
          jikanHasMore = false
          break
        }

        const loaded = await fetchAndApplyNextJikanPage(details.id_mal, requestVersion)
        if (requestVersion !== loadVersion || !details) return
        if (!loaded) break
      }
    } catch (e) {
      console.error('[TVDB][ui] jikan load-more failed', {
        malId: details.id_mal,
        page: jikanNextPage,
        error: e,
      })
    } finally {
      if (requestVersion === loadVersion) {
        jikanPaging = false
      }
    }
  }

  async function enrichEpisodes(d: AnimeDetails, requestVersion: number) {
    console.log('[TVDB][ui] enrichEpisodes start', {
      anilistId: d.id,
      format: d.format,
      idMal: d.id_mal,
      requestVersion,
    })

    let seededFromJikan = false
    let tvdbApplied = false
    if (!hasAnilistEpisodeBase && d.id_mal) {
      try {
        seededFromJikan = await seedJikanBaseEpisodes(d.id_mal, d.id, requestVersion)
      } catch (e) {
        console.error('[TVDB][ui] jikan base seed failed', {
          malId: d.id_mal,
          error: e,
        })
      }
    }

    try {
      const tvdbEps = await getTvdbEpisodes(d.id, d.format)
      if (requestVersion !== loadVersion || details?.id !== d.id) return

      console.log('[TVDB][ui] tvdb response', {
        anilistId: d.id,
        episodes: tvdbEps.length,
      })

      if (tvdbEps.length && details) {
        const hadEpisodeBase = details.episodes.length > 0
        const allowTvdbAppend = !hasAnilistEpisodeBase || seededFromJikan
        const tvdbNumbers = new Set(tvdbEps.map(ep => ep.number))
        const matchedBeforeApply = hadEpisodeBase
          ? details.episodes.reduce(
              (count, ep) => count + (tvdbNumbers.has(ep.number) ? 1 : 0),
              0
            )
          : 0

        details = applyEnrichedEpisodes(
          details,
          tvdbEps,
          'tvdb',
          !hadEpisodeBase || allowTvdbAppend
        )
        fallbackEpisodeCount = Math.max(fallbackEpisodeCount ?? 0, tvdbEps.length)
        tvdbApplied = hadEpisodeBase
          ? matchedBeforeApply > 0 || allowTvdbAppend
          : details.episodes.length > 0
        console.log('[TVDB][ui] tvdb enrichment applied', {
          anilistId: d.id,
          episodes: tvdbEps.length,
          matchedBaseEpisodes: matchedBeforeApply,
          appendMissing: !hadEpisodeBase || allowTvdbAppend,
          applied: tvdbApplied,
        })
      }
    } catch (e) {
      console.error('[TVDB][ui] tvdb enrichment failed', {
        anilistId: d.id,
        format: d.format,
        error: e,
      })
    }

    if (tvdbApplied) return

    if (!d.id_mal) {
      console.log('[TVDB][ui] skipping jikan fallback: missing MAL id', {
        anilistId: d.id,
      })
      return
    }

    if (seededFromJikan) return

    try {
      if (details?.episodes.length === 0) {
        const paged = await fetchJikanPage(d.id_mal, 1)
        if (requestVersion !== loadVersion || details?.id !== d.id) return

        console.log('[TVDB][ui] jikan paged response', {
          malId: d.id_mal,
          page: paged.page,
          episodes: paged.episodes.length,
          hasNextPage: paged.has_next_page,
        })

        const firstChunk = paged.episodes.slice(0, JIKAN_BATCH_SIZE)
        jikanBufferedEpisodes = paged.episodes.slice(firstChunk.length)

        if (firstChunk.length && details) {
          details = applyEnrichedEpisodes(details, firstChunk, 'jikan', !hasAnilistEpisodeBase)
        }
        jikanApiHasMore = paged.has_next_page
        jikanHasMore = jikanApiHasMore || jikanBufferedEpisodes.length > 0
        jikanNextPage = jikanApiHasMore ? paged.page + 1 : paged.page
      } else {
        const jikanEps = await getJikanEpisodes(d.id_mal)
        if (requestVersion !== loadVersion || details?.id !== d.id) return

        console.log('[TVDB][ui] jikan response', {
          malId: d.id_mal,
          episodes: jikanEps.length,
        })

        if (jikanEps.length && details) {
          details = applyEnrichedEpisodes(details, jikanEps, 'jikan', !hasAnilistEpisodeBase)
          fallbackEpisodeCount = Math.max(fallbackEpisodeCount ?? 0, jikanEps.length)
        }
        jikanHasMore = false
        jikanApiHasMore = false
        jikanBufferedEpisodes = []
      }
    } catch (e) {
      console.error('[TVDB][ui] jikan fallback failed', {
        malId: d.id_mal,
        error: e,
      })
    }
  }

  function formatStatus(status: string | null): string {
    if (!status) return ''
    return status.charAt(0) + status.slice(1).toLowerCase().replace(/_/g, ' ')
  }

  function formatSeason(season: string | null, year: number | null): string {
    if (!season) return ''
    const s = season.charAt(0) + season.slice(1).toLowerCase()
    return year ? `${s} ${year}` : s
  }
</script>

{#if loading}
  <LoadingScreen label="Loading anime details..." />

{:else if error}
  <p class="text-center py-12 text-red-500">{error}</p>

{:else if details}
  <div class="relative bg-black min-h-screen overflow-x-hidden">

    <!-- ── Hero ── -->
    <div
      class="relative min-h-[clamp(340px,52vh,580px)] bg-cover bg-top flex items-end"
      style="background-image: linear-gradient(96deg, rgba(0,0,0,0.92), rgba(0,0,0,0.55)),
             url('{details.banner_image ?? details.cover_image}')"
    >
      <!-- bottom fade -->
      <div class="absolute inset-0 bottom-[-1px] bg-gradient-to-b from-transparent via-transparent to-black pointer-events-none"></div>

      <div class="relative z-10 grid grid-cols-[minmax(160px,220px)_1fr] gap-6 items-end w-full
                  px-[clamp(1rem,2.5vw,2.5rem)] pt-[clamp(5rem,7vw,7rem)] pb-8 box-border">

        <!-- Poster -->
        <img
          src={details.cover_image}
          alt={details.title}
          class="w-full aspect-[2/3] object-cover rounded-xl border border-white/10
                 shadow-[0_16px_34px_rgba(0,0,0,0.6)]"
          loading="lazy"
        />

        <!-- Info -->
        <div class="grid gap-3 min-w-0">
          <h1 class="m-0 text-[clamp(1.6rem,3vw,2.8rem)] font-bold leading-[1.1]">
            {details.title}
          </h1>
          {#if details.title_japanese}
            <p class="m-0 text-[1.2rem] text-white/50">
              {details.title_japanese}
            </p>
          {/if}
          {#if details.studios.length}
            <span class="text-[0.7rem]">{details.studios[0]}</span>
          {/if}
          <!-- Chips -->
          <div class="flex flex-wrap gap-1.5">
            {#if details.format}
              <span class="chip">{details.format}</span>
            {/if}
            {#if details.status}
              <span class="chip">{formatStatus(details.status)}</span>
            {/if}
            {#if details.season || details.season_year}
              <span class="chip">{formatSeason(details.season, details.season_year)}</span>
            {/if}
            {#if details.episode_count}
              <span class="chip">{details.episode_count} EPS</span>
            {:else if resolvedEpisodeCount}
              <span class="chip">{resolvedEpisodeCount} EPS</span>
            {/if}
            {#if details.average_score}
              <span class="chip">{(details.average_score / 10).toFixed(1)} ★</span>
            {/if}
          </div>

          <!-- Genres -->
          <div class="flex flex-wrap gap-1.5">
            {#each details.genres as genre}
              <span class="text-[11px] px-2.5 py-1 rounded-full border border-white/10 bg-white/5">
                {genre}
              </span>
            {/each}
          </div>

          <!-- Description -->
          {#if details.description}
            <p class="m-0 text-white/65 text-[0.85rem] leading-[1.5] max-w-[74ch]
                      overflow-y-auto [max-height:calc(1.5em*4)]
                      [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              {@html details.description}
            </p>
          {/if}

          <!-- Actions -->
          <div class="flex gap-2 items-center flex-wrap mt-1">
            <a
              href="/watch/{details.id}?ep=1"
              class="inline-flex items-center gap-1.5 rounded-[10px] border border-white/15
                     bg-white/10 text-white px-3.5 py-[0.42rem] text-[0.82rem] no-underline
                     transition-colors hover:bg-white/16"
            >
              <PlayIcon size={14} weight="fill" />
              <span>Play</span>
            </a>
            <button
              class="inline-flex items-center justify-center w-[2.1rem] h-[2.1rem] rounded-[10px]
                     border border-white/15 bg-white/8 text-white transition-colors hover:bg-white/15"
              aria-label="Favorite"
            >
              <HeartIcon size={15} weight="regular" />
            </button>
          </div>
        </div>

      </div>
    </div>

    <!-- ── Content ── -->
    {#key details.id}
    <div class="relative z-10 grid gap-8 px-[clamp(1rem,2.5vw,2.5rem)] pt-6 pb-12 overflow-hidden">

      <EpisodeList
        episodes={details.episodes}
        cover_image={details.cover_image}
        anime_id={details.id}
        totalEpisodes={resolvedEpisodeCount}
        canLoadMore={jikanHasMore}
        loadingMore={jikanPaging}
        onLoadMore={onEpisodeListLoadMore}
      />

      <CharactersRow characters={details.characters} />


      <!-- Relations -->
      {#if details.relations.length}
        <section class="min-w-0">
          <AnimeRow
            title="Relations"
            items={details.relations}
            titleClass="text-[clamp(1.1rem,2vw,1.4rem)] font-semibold"
          />
        </section>
      {/if}

      <!-- Recommendations -->
      {#if details.recommendations.length}
        <section class="min-w-0">
          <AnimeRow
            title="Recommended"
            items={details.recommendations}
            titleClass="text-[clamp(1.1rem,2vw,1.4rem)] font-semibold"
          />
        </section>
      {/if}

      <!-- Trailer -->
      {#if details.trailer_id}
        <section class="grid gap-3 min-w-0">
          <h2 class="section-title">Trailer</h2>
          <iframe
            src="https://www.youtube-nocookie.com/embed/{details.trailer_id}"
            title="Trailer"
            class="w-full max-w-[560px] aspect-video rounded-xl border border-white/8"
            frameborder="0"
            allowfullscreen
          ></iframe>
        </section>
      {/if}
    </div>
    {/key}

  </div>
{/if}