<script lang="ts">
  import { onMount } from 'svelte'
  import { page } from '$app/stores'
  import { getAnimeDetails } from '$lib/api/anime'
  import type { AnimeDetails } from '$lib/types/anime'

  let details: AnimeDetails | null = null
  let loading = true
  let error: string | null = null

  onMount(async () => {
    try {
      const id = Number($page.params.id)
      details = await getAnimeDetails(id)
    } catch (e) {
      error = String(e)
    } finally {
      loading = false
    }
  })

  function formatStatus(status: string | null): string {
    if (!status) return ''
    return status.charAt(0) + status.slice(1).toLowerCase().replace('_', ' ')
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
  <div class="min-h-screen">

    <!-- Banner -->
    {#if details.banner_image}
      <div class="relative w-full h-[260px] overflow-hidden">
        <img
          src={details.banner_image}
          alt=""
          class="w-full h-full object-cover"
        />
        <div class="absolute inset-0 bg-gradient-to-b from-transparent to-background"></div>
      </div>
    {/if}

    <div class="flex gap-8 p-6 -mt-20 relative">

      <!-- Left -->
      <aside class="w-[180px] shrink-0">
        <img
          src={details.cover_image}
          alt={details.title}
          class="w-full aspect-[2/3] object-cover rounded-md"
        />

        <div class="mt-4 flex flex-col gap-2">

          {#if details.average_score}
            <div>
              <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
                Score
              </span>
              <span class="text-sm font-medium">
                {details.average_score / 10}
              </span>
            </div>
          {/if}

          {#if details.format}
            <div>
              <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
                Format
              </span>
              <span class="text-sm font-medium">{details.format}</span>
            </div>
          {/if}

          {#if details.episodes}
            <div>
              <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
                Episodes
              </span>
              <span class="text-sm font-medium">{details.episodes}</span>
            </div>
          {/if}

          {#if details.status}
            <div>
              <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
                Status
              </span>
              <span class="text-sm font-medium">
                {formatStatus(details.status)}
              </span>
            </div>
          {/if}

          {#if details.season || details.season_year}
            <div>
              <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
                Season
              </span>
              <span class="text-sm font-medium">
                {formatSeason(details.season, details.season_year)}
              </span>
            </div>
          {/if}

          {#if details.studios.length}
            <div>
              <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
                Studio
              </span>
              <span class="text-sm font-medium">
                {details.studios[0]}
              </span>
            </div>
          {/if}

        </div>
      </aside>

      <!-- Right -->
      <div class="flex-1 pt-[90px]">

        <h1 class="text-2xl font-bold mb-3">
          {details.title}
        </h1>

        <!-- Genres -->
        <div class="flex flex-wrap gap-2 mb-4">
          {#each details.genres as genre}
            <span class="text-xs px-3 py-1 rounded-full bg-muted text-foreground">
              {genre}
            </span>
          {/each}
        </div>

        <!-- Description -->
        {#if details.description}
          <p class="text-sm leading-relaxed text-muted-foreground max-w-[680px]">
            {details.description}
          </p>
        {/if}

        <!-- Trailer -->
        {#if details.trailer_id}
          <div class="mt-6">
            <h3 class="text-sm mb-2 opacity-70">Trailer</h3>

            <iframe
              src="https://www.youtube.com/embed/{details.trailer_id}"
              title="Trailer"
              class="w-full max-w-[560px] aspect-video rounded-md"
              frameborder="0"
              allowfullscreen
            ></iframe>
          </div>
        {/if}

      </div>
    </div>
  </div>
{/if}