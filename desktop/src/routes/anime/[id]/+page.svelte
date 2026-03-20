<script lang="ts">
  import { page } from '$app/stores'
  import { getAnimeDetails } from '$lib/api/anime'
  import type { AnimeDetails } from '$lib/types/anime'
  import { getTvdbEpisodes } from '$lib/api/tvdb'
  import { getJikanEpisodes } from '$lib/api/jikan'
  import type { TvdbEpisode } from '$lib/types/tvdb'
  import type { JikanEpisode } from '$lib/types/jikan'
  import AnimeRow from '$lib/components/AnimeRow.svelte'
  import { PlayIcon, HeartIcon } from 'phosphor-svelte'
  import EpisodeList from '$lib/components/EpisodeList.svelte'
  import CharactersRow from '$lib/components/CharectersRow.svelte'

  let details: AnimeDetails | null = null
  let loading = true
  let error: string | null = null

  $: id = Number($page.params.id)

  $: if (id) {
    loading = true
    error = null
    details = null
    console.log('[TVDB][ui] loading anime details', { id })
    getAnimeDetails(id)
      .then(d => {
        console.log('[TVDB][ui] anime details loaded', {
          id: d.id,
          format: d.format,
          id_mal: d.id_mal,
          episodeCount: d.episodes?.length ?? 0,
        })
        details = d
        enrichEpisodes(d)
      })
      .catch(e => {
        console.error('[TVDB][ui] getAnimeDetails failed', e)
        error = String(e)
      })
      .finally(() => { loading = false })
  }

  async function enrichEpisodes(d: AnimeDetails) {
    console.log('[TVDB][ui] enrichEpisodes start', {
      anilistId: d.id,
      format: d.format,
      idMal: d.id_mal,
    })

    try {
      const tvdbEps = await getTvdbEpisodes(d.id, d.format)
      console.log('[TVDB][ui] tvdb response', {
        anilistId: d.id,
        episodes: tvdbEps.length,
      })
      if (tvdbEps.length && details) {
        details = {
          ...details,
          episodes: details.episodes.map(ep => {
            const match = tvdbEps.find(t => t.number === Number(ep.number))
            if (!match) return ep
            return {
              ...ep,
              title:     match.title     ?? ep.title,
              thumbnail: match.thumbnail ?? ep.thumbnail,
            }
          })
        }
        console.log('[TVDB][ui] tvdb enrichment applied', {
          anilistId: d.id,
          episodes: tvdbEps.length,
        })
        return
      }
    } catch (e) {
      console.error('[TVDB][ui] tvdb enrichment failed', {
        anilistId: d.id,
        format: d.format,
        error: e,
      })
    }

    if (!d.id_mal) {
      console.log('[TVDB][ui] skipping jikan fallback: missing MAL id', {
        anilistId: d.id,
      })
      return
    }
    try {
      const jikanEps = await getJikanEpisodes(d.id_mal)
      console.log('[TVDB][ui] jikan response', {
        malId: d.id_mal,
        episodes: jikanEps.length,
      })
      if (jikanEps.length && details) {
        details = {
          ...details,
          episodes: details.episodes.map(ep => {
            const match = jikanEps.find(j => j.mal_id === Number(ep.number))
            if (!match) return ep
            return {
              ...ep,
              title: match.title ?? ep.title,
            }
          })
        }
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
  <p class="text-center py-12 opacity-50">Loading...</p>

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

      <EpisodeList episodes={details.episodes} cover_image={details.cover_image} anime_id={details.id}/>

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