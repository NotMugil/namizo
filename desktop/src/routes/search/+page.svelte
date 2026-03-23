<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import { discoverAnime } from "$lib/api/anime";
  import type { AnimeSummary } from "$lib/types/anime";
  import type { SearchPageItem } from "$lib/types/search";
  import {
    SEARCH_DEFAULT_FORMAT,
    SEARCH_DEFAULT_SORT,
    SEARCH_FORMAT_OPTIONS,
    SEARCH_GENRE_OPTIONS,
    SEARCH_SORT_OPTIONS,
  } from "$lib/constants/search";
  import {
    buildSearchDiscoverFilters,
    buildSearchFilterKey,
    buildSearchPageItems,
    findOptionLabel,
    perPageFromWidth,
    selectedGenreLabel,
  } from "$lib/utils/search";
  import AnimeCard from "$lib/components/AnimeCard.svelte";
  import SelectPicker from "$lib/components/ui/select/SelectPicker.svelte";
  import {
    Pagination,
    PaginationContent,
    PaginationEllipsis,
    PaginationItem,
    PaginationLink,
    PaginationNext,
    PaginationPrevious,
  } from "$lib/components/ui/pagination";
  import ChevronLeftIcon from "@lucide/svelte/icons/chevron-left";
  import ChevronRightIcon from "@lucide/svelte/icons/chevron-right";
  import {
    CaretDownIcon,
    CheckIcon,
    FunnelSimpleIcon,
    MagnifyingGlassIcon,
    SortAscendingIcon,
    TrashSimpleIcon,
  } from "phosphor-svelte";

  const sortOptions = SEARCH_SORT_OPTIONS;
  const formatOptions = SEARCH_FORMAT_OPTIONS;
  const genreOptions = SEARCH_GENRE_OPTIONS;

  let query = "";
  let results: AnimeSummary[] = [];
  let totalResults = 0;
  let page = 1;
  let pageCount = 1;
  let perPage = 24;
  let hasNextPage = false;
  let lastPage: number | null = null;

  let loading = false;
  let error: string | null = null;

  let selectedSort = SEARCH_DEFAULT_SORT;
  let selectedFormat = SEARCH_DEFAULT_FORMAT;
  let selectedGenres: string[] = [];
  let genreOpen = false;
  let genreLabel = "Genres";

  let pageItems: SearchPageItem[] = [];
  let paginationCount = perPage;
  let showPagination = false;
  let hasActiveFilters = false;
  let activeFilters: string[] = [];
  let previousFilterKey = `${SEARCH_DEFAULT_SORT}|${SEARCH_DEFAULT_FORMAT}|all`;

  let isReady = false;
  let searchDebounce: ReturnType<typeof setTimeout> | null = null;
  let activeRequestId = 0;
  let suppressNextPageFetch = false;
  let previousPageTriggerKey = "";
  let knownLastPage: number | null = null;

  function handleResize() {
    perPage = perPageFromWidth(window.innerWidth);
  }

  function syncQueryParam(rawQuery: string) {
    const normalized = rawQuery.trim();
    const url = new URL(window.location.href);

    if (normalized.length > 0) {
      url.searchParams.set("q", normalized);
    } else {
      url.searchParams.delete("q");
    }

    const next = `${url.pathname}${url.search}${url.hash}`;
    window.history.replaceState(window.history.state, "", next);
  }

  async function fetchResults(targetPage: number, rawQuery: string) {
    const requestId = ++activeRequestId;
    loading = true;
    error = null;

    try {
      const response = await discoverAnime(
        buildSearchDiscoverFilters(
          rawQuery,
          selectedSort,
          selectedFormat,
          selectedGenres,
        ),
        Math.max(1, targetPage),
        perPage,
      );

      if (requestId !== activeRequestId) return;

      results = response.items;
      hasNextPage = response.has_next_page;
      lastPage = response.last_page;
      const normalizedQuery = rawQuery.trim();
      const hasNarrowingInput =
        normalizedQuery.length > 0 ||
        selectedFormat !== "all" ||
        selectedGenres.length > 0;
      const isCappedServerTotal =
        hasNarrowingInput && response.total !== null && response.total >= 5000;
      const currentPage =
        response.current_page > 0
          ? response.current_page
          : Math.max(1, targetPage);

      if (currentPage > 1 && response.items.length === 0) {
        const fallbackPage = currentPage - 1;
        knownLastPage = fallbackPage;
        suppressNextPageFetch = true;
        page = fallbackPage;
        pageCount = fallbackPage;
        pageItems = buildSearchPageItems(pageCount, page, 1);
        paginationCount = Math.max(perPage, pageCount * perPage);
        showPagination = pageCount > 1;
        void fetchResults(fallbackPage, rawQuery);
        return;
      }

      const visibleCount = Math.max(
        0,
        (currentPage - 1) * perPage + response.items.length,
      );
      const reliableTotalPages =
        !isCappedServerTotal && response.total !== null
          ? Math.max(1, Math.ceil(response.total / perPage))
          : null;

      totalResults = isCappedServerTotal
        ? visibleCount
        : (response.total ?? visibleCount);
      page = currentPage;

      if (reliableTotalPages !== null) {
        knownLastPage = reliableTotalPages;
      } else if (!isCappedServerTotal) {
        knownLastPage =
          response.last_page ?? (response.has_next_page ? null : currentPage);
      } else if (!response.has_next_page || response.items.length < perPage) {
        knownLastPage = currentPage;
      }

      const effectivePageCount =
        knownLastPage ??
        (response.has_next_page ? currentPage + 1 : currentPage);
      pageCount = Math.max(1, effectivePageCount);

      pageItems = buildSearchPageItems(pageCount, page, 1);
      paginationCount = Math.max(
        perPage,
        pageCount * perPage + (knownLastPage === null && hasNextPage ? 1 : 0),
      );
      showPagination = page > 1 || hasNextPage || pageCount > 1;
    } catch (e) {
      if (requestId !== activeRequestId) return;
      error = String(e);
      results = [];
      totalResults = 0;
      hasNextPage = false;
      lastPage = null;
      pageCount = 1;
      pageItems = buildSearchPageItems(1, 1, 1);
      paginationCount = perPage;
      showPagination = false;
    } finally {
      if (requestId === activeRequestId) {
        loading = false;
      }
    }
  }

  function clearFilters() {
    selectedSort = SEARCH_DEFAULT_SORT;
    selectedFormat = SEARCH_DEFAULT_FORMAT;
    selectedGenres = [];
  }

  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    query = params.get("q")?.trim() ?? "";

    perPage = perPageFromWidth(window.innerWidth);
    window.addEventListener("resize", handleResize, { passive: true });
    isReady = true;
  });

  onDestroy(() => {
    window.removeEventListener("resize", handleResize);
    activeRequestId += 1;
    if (searchDebounce) {
      clearTimeout(searchDebounce);
      searchDebounce = null;
    }
  });

  $: hasActiveFilters =
    selectedSort !== SEARCH_DEFAULT_SORT ||
    selectedFormat !== SEARCH_DEFAULT_FORMAT ||
    selectedGenres.length > 0;

  $: genreLabel = selectedGenreLabel(selectedGenres);

  $: activeFilters = [
    ...(selectedSort !== SEARCH_DEFAULT_SORT
      ? [findOptionLabel(sortOptions, selectedSort)]
      : []),
    ...(selectedFormat !== SEARCH_DEFAULT_FORMAT
      ? [findOptionLabel(formatOptions, selectedFormat)]
      : []),
    ...selectedGenres,
  ];

  $: clearButtonClass = hasActiveFilters
    ? "rounded-md bg-red-500/18 px-3 py-1 text-[0.68rem] font-medium text-red-200 transition hover:bg-red-500/28"
    : "rounded-md bg-white/10 px-3 py-1 text-[0.68rem] font-medium text-white/70 transition hover:bg-white/16";

  $: if (isReady) {
    const filterKey = buildSearchFilterKey(
      query,
      selectedSort,
      selectedFormat,
      selectedGenres,
      perPage,
    );
    if (filterKey !== previousFilterKey) {
      previousFilterKey = filterKey;
      knownLastPage = null;
      suppressNextPageFetch = true;
      page = 1;

      if (searchDebounce) {
        clearTimeout(searchDebounce);
      }

      searchDebounce = setTimeout(() => {
        syncQueryParam(query);
        void fetchResults(1, query);
      }, 260);
    }
  }

  $: if (isReady) {
    const pageTriggerKey = `${previousFilterKey}|${page}`;
    if (pageTriggerKey !== previousPageTriggerKey) {
      previousPageTriggerKey = pageTriggerKey;
      if (suppressNextPageFetch) {
        suppressNextPageFetch = false;
      } else {
        void fetchResults(page, query);
      }
    }
  }
</script>

<svelte:window onclick={() => (genreOpen = false)} />

<section class="px-6 pt-20 pb-4">
  <div class="p-3 sm:p-4">
    <div class="flex flex-wrap items-center gap-2">
      <div class="flex flex-1 items-center gap-2">
        <label class="relative min-w-[220px] flex-[1_1_280px]">
          <MagnifyingGlassIcon
            size={13}
            weight="bold"
            class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-white/45"
          />
          <input
            bind:value={query}
            placeholder="Search anime..."
            class="h-9 w-full rounded-[10px] border pl-8 pr-3 text-sm text-white outline-none placeholder:text-white/35"
          />
        </label>
        <button
          type="button"
          class={`inline-flex h-9 w-10 items-center justify-center rounded-[10px] border border-white/12 text-white transition ${clearButtonClass}`}
          onclick={clearFilters}
          aria-label="Clear filters"
        >
          <TrashSimpleIcon size={14} weight="bold" />
        </button>
      </div>

      <SelectPicker items={sortOptions} bind:value={selectedSort}>
        {#snippet prefix()}
          <SortAscendingIcon size={12} weight="bold" class="text-white/62" />
        {/snippet}
      </SelectPicker>

      <SelectPicker items={formatOptions} bind:value={selectedFormat}>
        {#snippet prefix()}
          <FunnelSimpleIcon size={12} weight="bold" class="text-white/62" />
        {/snippet}
      </SelectPicker>

      <div class="relative">
        <button
          type="button"
          class="inline-flex h-9 min-w-[130px] items-center justify-between gap-2 rounded-[10px] border border-white/12 bg-black/62 px-3 text-sm text-white/86 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] backdrop-blur-[16px] outline-none transition hover:border-white/22"
          onclick={(event) => {
            event.stopPropagation();
            genreOpen = !genreOpen;
          }}
        >
          <span class="inline-flex min-w-0 items-center gap-1.5">
            <FunnelSimpleIcon size={12} weight="bold" class="text-white/62" />
            <span class="truncate">{genreLabel}</span>
          </span>
          <CaretDownIcon
            size={12}
            weight="bold"
            class="shrink-0 text-white/58"
          />
        </button>

        {#if genreOpen}
          <div
            class="absolute right-0 z-[90] mt-2 max-h-64 min-w-[200px] overflow-y-auto rounded-[10px] border border-white/14 bg-black/72 p-1 text-white shadow-[0_16px_42px_rgba(0,0,0,0.62)] backdrop-blur-[22px]"
          >
            <button
              type="button"
              class="mb-1 h-8 w-full rounded-[7px] px-2 text-left text-[0.82rem] text-white/80 transition hover:bg-white/[0.10] hover:text-white"
              onclick={(event) => {
                event.stopPropagation();
                selectedGenres = [];
              }}
            >
              Clear genres
            </button>
            {#each genreOptions as genre}
              <button
                type="button"
                class="flex h-8 w-full items-center justify-between gap-2 rounded-[7px] px-2 text-left text-[0.82rem] text-white/78 transition hover:bg-white/[0.10] hover:text-white"
                onclick={(event) => {
                  event.stopPropagation();
                  if (selectedGenres.includes(genre)) {
                    selectedGenres = selectedGenres.filter(
                      (value) => value !== genre,
                    );
                  } else {
                    selectedGenres = [...selectedGenres, genre];
                  }
                }}
              >
                <span class="truncate">{genre}</span>
                <CheckIcon
                  size={12}
                  weight="bold"
                  class={selectedGenres.includes(genre)
                    ? "text-white/90"
                    : "text-transparent"}
                />
              </button>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <div class="mt-3 flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-wrap items-center gap-2">
        <span
          class="rounded-md bg-white/[0.06] px-3 py-1 text-[0.68rem] text-white/76"
        >
          {totalResults} results
        </span>
        {#each activeFilters as filter (filter)}
          <span
            class="rounded-md border border-white/12 bg-white/[0.04] px-2.5 py-1 text-[0.68rem] text-white/78"
          >
            {filter}
          </span>
        {/each}
      </div>

      {#if showPagination}
        <div class="ml-auto">
          <Pagination
            count={paginationCount}
            bind:page
            {perPage}
            siblingCount={1}
            class="w-auto justify-end"
          >
            <PaginationContent>
              <PaginationItem>
                <PaginationPrevious
                  class="h-8 min-w-8 rounded-md border-0 bg-transparent px-2 text-white/70 shadow-none hover:bg-white/10 hover:text-white dark:hover:bg-white/10"
                >
                  {#snippet children()}
                    <ChevronLeftIcon class="size-4" />
                  {/snippet}
                </PaginationPrevious>
              </PaginationItem>
              {#each pageItems as item (item.key)}
                <PaginationItem>
                  {#if item.type === "ellipsis"}
                    <PaginationEllipsis class="size-8 text-white/40" />
                  {:else}
                    <PaginationLink
                      page={item}
                      isActive={page === item.value}
                      size="icon-sm"
                      class={page === item.value
                        ? "h-8 min-w-8 rounded-md border border-white/20 bg-white/12 text-white shadow-none hover:bg-white/18 dark:bg-white/12 dark:hover:bg-white/18"
                        : "h-8 min-w-8 rounded-md border-0 bg-transparent text-white/70 shadow-none hover:bg-white/10 hover:text-white dark:hover:bg-white/10"}
                    />
                  {/if}
                </PaginationItem>
              {/each}
              <PaginationItem>
                <PaginationNext
                  class="h-8 min-w-8 rounded-md border-0 bg-transparent px-2 text-white/70 shadow-none hover:bg-white/10 hover:text-white dark:hover:bg-white/10"
                >
                  {#snippet children()}
                    <ChevronRightIcon class="size-4" />
                  {/snippet}
                </PaginationNext>
              </PaginationItem>
            </PaginationContent>
          </Pagination>
        </div>
      {/if}
    </div>
  </div>
</section>

<section class="px-6 pb-10">
  <div class="p-3 sm:p-4">
    {#if loading}
      <div
        class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 2xl:grid-cols-8"
      >
        {#each Array.from({ length: perPage }) as _, index (index)}
          <div class="space-y-2">
            <div
              class="aspect-[2/3] animate-pulse rounded-lg bg-white/[0.06]"
            ></div>
            <div
              class="h-3 w-[75%] animate-pulse rounded bg-white/[0.06]"
            ></div>
            <div
              class="h-2.5 w-[45%] animate-pulse rounded bg-white/[0.05]"
            ></div>
          </div>
        {/each}
      </div>
    {:else if error}
      <div class="rounded-xl bg-red-950/35 px-4 py-3 text-sm text-red-200">
        {error}
      </div>
    {:else if results.length === 0}
      <div
        class="rounded-xl bg-muted/30 px-4 py-12 text-center text-sm font-mono text-white/58"
      >
        No anime matches your current query and filters.
      </div>
    {:else}
      <div
        class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 2xl:grid-cols-8"
      >
        {#each results as anime (anime.id)}
          <AnimeCard {anime} fluid />
        {/each}
      </div>

      {#if showPagination}
        <div class="mt-6">
          <Pagination
            count={paginationCount}
            bind:page
            {perPage}
            siblingCount={1}
          >
            <PaginationContent>
              <PaginationItem>
                <PaginationPrevious
                  class="h-8 min-w-8 rounded-md border-0 bg-transparent px-2 text-white/70 shadow-none hover:bg-white/10 hover:text-white dark:hover:bg-white/10"
                >
                  {#snippet children()}
                    <ChevronLeftIcon class="size-4" />
                  {/snippet}
                </PaginationPrevious>
              </PaginationItem>
              {#each pageItems as item (item.key)}
                <PaginationItem>
                  {#if item.type === "ellipsis"}
                    <PaginationEllipsis class="size-8 text-white/40" />
                  {:else}
                    <PaginationLink
                      page={item}
                      isActive={page === item.value}
                      size="icon-sm"
                      class={page === item.value
                        ? "h-8 min-w-8 rounded-md border border-white/20 bg-white/12 text-white shadow-none hover:bg-white/18 dark:bg-white/12 dark:hover:bg-white/18"
                        : "h-8 min-w-8 rounded-md border-0 bg-transparent text-white/70 shadow-none hover:bg-white/10 hover:text-white dark:hover:bg-white/10"}
                    />
                  {/if}
                </PaginationItem>
              {/each}
              <PaginationItem>
                <PaginationNext
                  class="h-8 min-w-8 rounded-md border-0 bg-transparent px-2 text-white/70 shadow-none hover:bg-white/10 hover:text-white dark:hover:bg-white/10"
                >
                  {#snippet children()}
                    <ChevronRightIcon class="size-4" />
                  {/snippet}
                </PaginationNext>
              </PaginationItem>
            </PaginationContent>
          </Pagination>
        </div>
      {/if}
    {/if}
  </div>
</section>