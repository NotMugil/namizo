<script lang="ts">
  import { goto } from "$app/navigation";
  import type { AnimeSummary } from "$lib/types/anime";
  import { onDestroy, onMount, tick } from "svelte";
  import { Portal } from "bits-ui";
  import { FunnelSimpleIcon, MagnifyingGlassIcon } from "phosphor-svelte";
  import { ROUTES } from "$lib/constants/routes";
  import { searchAnime } from "$lib/api/anime";

  let isSpotlightOpen = $state(false);
  let spotlightQuery = $state("");
  let spotlightResults = $state<AnimeSummary[]>([]);
  let spotlightLoading = $state(false);
  let spotlightError = $state<string | null>(null);
  let selectedIndex = $state(0);
  let isMac = $state(false);

  let spotlightInput = $state<HTMLInputElement | null>(null);
  let searchRequestVersion = 0;
  let searchDebounce: ReturnType<typeof setTimeout> | null = null;
  let previousBodyOverflow = "";
  let previousHtmlOverflow = "";

  const shortcutLabel = $derived(isMac ? "Cmd K" : "Ctrl K");
  const showSpotlightResults = $derived(spotlightQuery.trim().length >= 2);

  async function focusSpotlightInput() {
    await tick();
    spotlightInput?.focus();
    spotlightInput?.select();
  }

  function openSpotlight(prefill = "") {
    isSpotlightOpen = true;
    spotlightQuery = prefill;
    spotlightError = null;
    selectedIndex = 0;
    void focusSpotlightInput();
  }

  function closeSpotlight() {
    isSpotlightOpen = false;
    spotlightQuery = "";
    spotlightResults = [];
    spotlightLoading = false;
    spotlightError = null;
    selectedIndex = 0;
    searchRequestVersion += 1;

    if (searchDebounce) {
      clearTimeout(searchDebounce);
      searchDebounce = null;
    }
  }

  async function runSpotlightSearch(rawQuery: string) {
    const query = rawQuery.trim();
    if (query.length < 2) {
      spotlightResults = [];
      spotlightLoading = false;
      spotlightError = null;
      selectedIndex = 0;
      return;
    }

    const requestVersion = ++searchRequestVersion;
    spotlightLoading = true;
    spotlightError = null;

    try {
      const results = await searchAnime(query);
      if (requestVersion !== searchRequestVersion) return;

      spotlightResults = results.slice(0, 8);
      selectedIndex = 0;
    } catch (e) {
      if (requestVersion !== searchRequestVersion) return;
      spotlightError = String(e);
      spotlightResults = [];
    } finally {
      if (requestVersion === searchRequestVersion) {
        spotlightLoading = false;
      }
    }
  }

  async function openAnime(id: number) {
    closeSpotlight();
    await goto(`/anime/${id}`);
  }

  async function openDiscoverFromSpotlight() {
    const query = spotlightQuery.trim();
    closeSpotlight();
    await goto(
      query.length > 0
        ? `${ROUTES.DISCOVER}?q=${encodeURIComponent(query)}`
        : ROUTES.DISCOVER,
    );
  }

  async function openSearchPageFromSpotlight() {
    const query = spotlightQuery.trim();
    closeSpotlight();
    await goto(
      query.length > 0
        ? `${ROUTES.DISCOVER}?q=${encodeURIComponent(query)}`
        : ROUTES.DISCOVER,
    );
  }

  async function handleGlobalKeydown(event: KeyboardEvent) {
    const key = event.key.toLowerCase();
    if ((event.metaKey || event.ctrlKey) && key === "k") {
      event.preventDefault();
      if (!isSpotlightOpen) openSpotlight();
      return;
    }

    if (!isSpotlightOpen) return;

    if (event.key === "Escape") {
      event.preventDefault();
      closeSpotlight();
      return;
    }

    if (event.key === "Enter" && !showSpotlightResults) {
      if (spotlightQuery.trim().length >= 2) {
        event.preventDefault();
        await openDiscoverFromSpotlight();
      }
      return;
    }

    if (!showSpotlightResults || spotlightResults.length === 0) return;

    if (event.key === "ArrowDown") {
      event.preventDefault();
      selectedIndex = (selectedIndex + 1) % spotlightResults.length;
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      selectedIndex =
        (selectedIndex - 1 + spotlightResults.length) % spotlightResults.length;
      return;
    }

    if (event.key === "Enter") {
      event.preventDefault();
      const selected = spotlightResults[selectedIndex] ?? spotlightResults[0];
      if (selected) {
        await openAnime(selected.id);
      } else {
        await openDiscoverFromSpotlight();
      }
    }
  }

  $effect(() => {
    if (!isSpotlightOpen) return;

    const query = spotlightQuery;
    if (searchDebounce) clearTimeout(searchDebounce);
    searchDebounce = setTimeout(() => {
      void runSpotlightSearch(query);
    }, 220);

    return () => {
      if (searchDebounce) {
        clearTimeout(searchDebounce);
        searchDebounce = null;
      }
    };
  });

  $effect(() => {
    if (!isSpotlightOpen) return;

    previousBodyOverflow = document.body.style.overflow;
    previousHtmlOverflow = document.documentElement.style.overflow;

    document.body.style.overflow = "hidden";
    document.documentElement.style.overflow = "hidden";

    return () => {
      document.body.style.overflow = previousBodyOverflow;
      document.documentElement.style.overflow = previousHtmlOverflow;
    };
  });

  onMount(() => {
    isMac = navigator.platform.toLowerCase().includes("mac");
    window.addEventListener("keydown", handleGlobalKeydown);
  });

  onDestroy(() => {
    window.removeEventListener("keydown", handleGlobalKeydown);

    if (searchDebounce) {
      clearTimeout(searchDebounce);
      searchDebounce = null;
    }
  });
</script>

<button
  type="button"
  onclick={() => openSpotlight()}
  class="group hidden h-10 min-w-[12rem] items-center justify-between gap-3 rounded-full border border-white/10 bg-black/55 px-4 text-left shadow-[0_10px_24px_rgba(0,0,0,0.5)] backdrop-blur-[18px] transition hover:border-white/20 hover:bg-black/65 md:flex md:w-[min(30vw,22rem)]"
  aria-label="Open search spotlight"
>
  <span class="inline-flex min-w-0 items-center gap-2 text-sm text-white/72 transition group-hover:text-white">
    <MagnifyingGlassIcon size={16} weight="bold" />
    <span class="truncate">Search...</span>
  </span>
  <span class="rounded-md border border-white/14 bg-white/[0.06] px-2 py-1 text-[11px] font-medium text-white/60">
    {shortcutLabel}
  </span>
</button>

<button
  type="button"
  onclick={() => openSpotlight()}
  class="inline-flex h-9 w-9 items-center justify-center rounded-md border border-white/12 bg-black/55 text-white/80 backdrop-blur-[12px] transition hover:bg-black/70 md:hidden"
  aria-label="Open search spotlight"
>
  <MagnifyingGlassIcon size={18} weight="bold" />
</button>

{#if isSpotlightOpen}
  <Portal>
    <div class="fixed inset-0 z-[120] bg-black/66 backdrop-blur-[3px]">
      <button
        type="button"
        aria-label="Close search spotlight"
        class="absolute inset-0"
        onclick={closeSpotlight}
      ></button>

      <div class="pointer-events-none fixed inset-x-0 top-16 mx-auto w-full max-w-3xl px-3 sm:top-20 sm:px-6">
        <div
          class="pointer-events-auto overflow-hidden rounded-[14px] border border-white/12 bg-black/72 shadow-[0_34px_90px_rgba(0,0,0,0.76)] backdrop-blur-[26px]"
          role="dialog"
          aria-modal="true"
          aria-label="Search Spotlight"
        >
          <div class="flex items-center gap-3 border-b border-white/10 px-4 py-3">
            <MagnifyingGlassIcon size={18} weight="bold" class="text-white/65" />
            <input
              bind:this={spotlightInput}
              bind:value={spotlightQuery}
              placeholder="Search anime titles..."
              class="h-11 w-full bg-transparent text-[0.96rem] text-white outline-none placeholder:text-white/34"
            />
            <button
              type="button"
              class="inline-flex h-8 w-8 items-center justify-center rounded-md text-white/74 outline-none transition hover:bg-white/[0.08] hover:text-white focus-visible:outline-none focus-visible:ring-0"
              onclick={() => {
                void openSearchPageFromSpotlight();
              }}
              aria-label="Open search page"
            >
              <FunnelSimpleIcon size={13} weight="bold" />
            </button>
            <button
              type="button"
              onclick={closeSpotlight}
              class="rounded-md border border-white/12 bg-white/[0.05] px-2 py-1 text-[11px] text-white/60 transition hover:text-white"
            >
              Esc
            </button>
          </div>

          <div class="max-h-[64vh] overflow-y-auto">
            {#if showSpotlightResults}
              {#if spotlightLoading}
                <div class="space-y-0 p-0">
                  {#each Array.from({ length: 4 }) as _, idx (idx)}
                    <div class="h-16 animate-pulse border-b border-white/7 bg-white/[0.03]"></div>
                  {/each}
                </div>
              {:else if spotlightError}
                <p class="m-3 rounded-md border border-red-400/30 bg-red-950/35 p-3 text-sm text-red-200">
                  {spotlightError}
                </p>
              {:else if spotlightResults.length === 0}
                <div class="m-3 rounded-md border border-white/10 bg-white/[0.03] p-4 text-center text-sm text-white/60">
                  No matches for <span class="text-white">"{spotlightQuery.trim()}"</span>.
                </div>
              {:else}
                <div class="space-y-0">
                  {#each spotlightResults as anime, idx (anime.id)}
                    <button
                      type="button"
                      onclick={() => {
                        void openAnime(anime.id);
                      }}
                      onmouseenter={() => {
                        selectedIndex = idx;
                      }}
                      class={`flex w-full items-center gap-3 border-b border-white/8 px-3 py-2.5 text-left transition ${
                        selectedIndex === idx
                          ? "bg-white/[0.12]"
                          : "bg-white/[0.02] hover:bg-white/[0.07]"
                      }`}
                    >
                      <img
                        src={anime.banner_image ?? anime.cover_image}
                        alt={anime.title}
                        class="h-11 w-20 rounded-md object-cover sm:h-12 sm:w-20"
                        loading="lazy"
                      />
                      <div class="min-w-0 flex-1">
                        <p class="truncate text-sm font-medium text-white">{anime.title}</p>
                        <p class="mt-0.5 truncate text-xs text-white/56">
                          {anime.format ?? "ANIME"}
                          {#if anime.episodes}
                            {" - "}{anime.episodes} episodes
                          {/if}
                        </p>
                      </div>
                      {#if anime.average_score}
                        <span class="rounded-full border border-white/18 bg-white/[0.08] px-2 py-0.5 text-[11px] text-white/75">
                          {(anime.average_score / 10).toFixed(1)}
                        </span>
                      {/if}
                    </button>
                  {/each}
                </div>

                <button
                  type="button"
                  class="w-full bg-black/35 px-3 py-2.5 text-left text-sm text-white/74 transition hover:bg-white/[0.08]"
                  onclick={() => {
                    void openDiscoverFromSpotlight();
                  }}
                >
                  View full results for "{spotlightQuery.trim()}"
                </button>
              {/if}
            {/if}
          </div>
        </div>
      </div>
    </div>
  </Portal>
{/if}