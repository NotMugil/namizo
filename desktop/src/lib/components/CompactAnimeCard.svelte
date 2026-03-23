<script lang="ts">
  import { goto } from "$app/navigation";
  import type { AnimeSummary } from "$lib/types/anime";

  export let anime: AnimeSummary;
</script>

<button
  type="button"
  class="group flex h-full w-full min-w-0 cursor-pointer flex-col border-0 bg-transparent p-0 text-left text-inherit"
  onclick={() => goto(`/anime/${anime.id}`)}
>
  <div
    class="relative aspect-[2/3] overflow-hidden rounded-lg bg-black/45 ring-1 ring-white/8 transition duration-200 group-hover:ring-white/18"
  >
    <img
      src={anime.cover_image}
      alt={anime.title}
      class="h-full w-full object-cover transition duration-300 group-hover:scale-[1.02]"
      loading="lazy"
    />
    {#if anime.average_score}
      <span
        class="absolute right-1.5 top-1.5 rounded-full bg-black/72 px-2 py-0.5 text-[0.63rem] font-semibold text-white/86"
      >
        {(anime.average_score / 10).toFixed(1)}
      </span>
    {/if}
  </div>

  <div class="mt-2 min-w-0 space-y-0.5 px-0.5">
    <p class="line-clamp-2 min-h-[2rem] text-[0.82rem] leading-tight text-white/92">{anime.title}</p>
    <p class="truncate text-[0.67rem] uppercase tracking-[0.04em] text-white/48">
      {anime.format ?? "ANIME"}
      {#if anime.episodes}
        {" · "}{anime.episodes} eps
      {/if}
    </p>
  </div>
</button>