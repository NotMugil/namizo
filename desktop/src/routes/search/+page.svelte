<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import { discoverAnime } from "$lib/api/anime";
  import type { AnimeSummary, DiscoverFilters } from "$lib/types/anime";
  import CompactAnimeCard from "$lib/components/CompactAnimeCard.svelte";
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
  import { FunnelSimpleIcon, MagnifyingGlassIcon, SortAscendingIcon } from "phosphor-svelte";

  const sortOptions = [
    { value: "POPULARITY_DESC", label: "Popularity" },
    { value: "SCORE_DESC", label: "Score" },
    { value: "TITLE_ROMAJI", label: "Title A-Z" },
    { value: "EPISODES_DESC", label: "Episodes" },
  ];

  const formatOptions = [
    { value: "all", label: "All Formats" },
    { value: "TV", label: "TV" },
    { value: "MOVIE", label: "Movie" },
    { value: "OVA", label: "OVA" },
    { value: "ONA", label: "ONA" },
    { value: "SPECIAL", label: "Special" },
    { value: "MUSIC", label: "Music" },
  ];

  const genreOptions = [
    { value: "all", label: "All Genres" },
    { value: "Action", label: "Action" },
    { value: "Adventure", label: "Adventure" },
    { value: "Comedy", label: "Comedy" },
    { value: "Drama", label: "Drama" },
    { value: "Fantasy", label: "Fantasy" },
    { value: "Horror", label: "Horror" },
    { value: "Mahou Shoujo", label: "Mahou Shoujo" },
    { value: "Mecha", label: "Mecha" },
    { value: "Music", label: "Music" },
    { value: "Mystery", label: "Mystery" },
    { value: "Psychological", label: "Psychological" },
    { value: "Romance", label: "Romance" },
    { value: "Sci-Fi", label: "Sci-Fi" },
    { value: "Slice of Life", label: "Slice of Life" },
    { value: "Sports", label: "Sports" },
    { value: "Supernatural", label: "Supernatural" },
    { value: "Thriller", label: "Thriller" },
  ];

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

  let selectedSort = "POPULARITY_DESC";
  let selectedFormat = "all";
  let selectedGenre = "all";

  let pageItems: Array<
    | { key: string; type: "page"; value: number }
    | { key: string; type: "ellipsis" }
  > = [];
  let paginationCount = perPage;
  let showPagination = false;
  let hasActiveFilters = false;
  let previousFilterKey = "POPULARITY_DESC|all|all";

  let isReady = false;
  let searchDebounce: ReturnType<typeof setTimeout> | null = null;
  let activeRequestId = 0;
  let suppressNextPageFetch = false;
  let previousPageTriggerKey = "";
  let knownLastPage: number | null = null;

  function getColumns(width: number): number {
    if (width >= 1536) return 8; // 2xl:grid-cols-8
    if (width >= 1280) return 7; // xl:grid-cols-7
    if (width >= 1024) return 6; // lg:grid-cols-6
    if (width >= 768) return 4; // md:grid-cols-4
    if (width >= 640) return 3; // sm:grid-cols-3
    return 2;
  }

  function syncPerPage(width: number) {
    const columns = getColumns(width);
    perPage = columns * 3;
  }

  function handleResize() {
    syncPerPage(window.innerWidth);
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

  function buildPageItems(
    totalPages: number,
    currentPage: number,
    siblingCount = 1,
  ): Array<{ key: string; type: "page"; value: number } | { key: string; type: "ellipsis" }> {
    if (totalPages <= 0) return [];
    if (totalPages === 1) {
      return [{ key: "page-1", type: "page", value: 1 }];
    }

    const items: Array<
      { key: string; type: "page"; value: number } | { key: string; type: "ellipsis" }
    > = [];

    items.push({ key: "page-1", type: "page", value: 1 });

    const left = Math.max(2, currentPage - siblingCount);
    const right = Math.min(totalPages - 1, currentPage + siblingCount);

    if (left > 2) {
      items.push({ key: `ellipsis-left-${left}`, type: "ellipsis" });
    }

    for (let value = left; value <= right; value += 1) {
      items.push({ key: `page-${value}`, type: "page", value });
    }

    if (right < totalPages - 1) {
      items.push({ key: `ellipsis-right-${right}`, type: "ellipsis" });
    }

    items.push({ key: `page-${totalPages}`, type: "page", value: totalPages });

    return items;
  }

  function buildDiscoverFilters(rawQuery: string): DiscoverFilters {
    const normalized = rawQuery.trim();
    return {
      search: normalized.length > 0 ? normalized : undefined,
      genres: selectedGenre !== "all" ? [selectedGenre] : undefined,
      formats: selectedFormat !== "all" ? [selectedFormat] : undefined,
      sort: [selectedSort],
      is_adult: false,
    };
  }

  async function fetchResults(targetPage: number, rawQuery: string) {
    const requestId = ++activeRequestId;
    loading = true;
    error = null;

    try {
      const response = await discoverAnime(
        buildDiscoverFilters(rawQuery),
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
        selectedGenre !== "all";
      const isCappedServerTotal =
        hasNarrowingInput &&
        response.total !== null &&
        response.total >= 5000;
      const currentPage =
        response.current_page > 0 ? response.current_page : Math.max(1, targetPage);

      if (currentPage > 1 && response.items.length === 0) {
        const fallbackPage = currentPage - 1;
        knownLastPage = fallbackPage;
        suppressNextPageFetch = true;
        page = fallbackPage;
        pageCount = fallbackPage;
        pageItems = buildPageItems(pageCount, page, 1);
        paginationCount = Math.max(perPage, pageCount * perPage);
        showPagination = pageCount > 1;
        void fetchResults(fallbackPage, rawQuery);
        return;
      }

      const visibleCount = Math.max(0, (currentPage - 1) * perPage + response.items.length);
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
        knownLastPage = response.last_page ?? (response.has_next_page ? null : currentPage);
      } else if (!response.has_next_page || response.items.length < perPage) {
        knownLastPage = currentPage;
      }

      const effectivePageCount = knownLastPage ?? (response.has_next_page ? currentPage + 1 : currentPage);
      pageCount = Math.max(1, effectivePageCount);

      pageItems = buildPageItems(pageCount, page, 1);
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
      pageItems = buildPageItems(1, 1, 1);
      paginationCount = perPage;
      showPagination = false;
    } finally {
      if (requestId === activeRequestId) {
        loading = false;
      }
    }
  }

  function clearFilters() {
    selectedSort = "POPULARITY_DESC";
    selectedFormat = "all";
    selectedGenre = "all";
  }

  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    query = params.get("q")?.trim() ?? "";

    syncPerPage(window.innerWidth);
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
    selectedSort !== "POPULARITY_DESC" ||
    selectedFormat !== "all" ||
    selectedGenre !== "all";

  $: if (isReady) {
    const filterKey = `${query.trim()}|${selectedSort}|${selectedFormat}|${selectedGenre}|${perPage}`;
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

<section class="px-6 pt-20 pb-4">
  <div class="p-3 sm:p-4">
    <div class="flex flex-wrap items-center gap-2">
      <label class="relative min-w-[220px] flex-[1_1_280px]">
        <MagnifyingGlassIcon
          size={13}
          weight="bold"
          class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-white/45"
        />
        <input
          bind:value={query}
          placeholder="Search anime..."
          class="h-9 w-full rounded-[10px] bg-muted/60 pl-8 pr-3 text-sm text-white outline-none placeholder:text-white/35"
        />
      </label>

      <SelectPicker
        items={sortOptions}
        bind:value={selectedSort}
        triggerClass="h-9 min-w-[126px] rounded-[10px] border-0 bg-muted/60 px-2.5 shadow-none hover:border-0 focus-visible:border-0"
      >
        {#snippet prefix()}
          <SortAscendingIcon size={12} weight="bold" class="text-white/62" />
        {/snippet}
      </SelectPicker>

      <SelectPicker
        items={formatOptions}
        bind:value={selectedFormat}
        triggerClass="h-9 min-w-[132px] rounded-[10px] border-0 bg-muted/60 px-2.5 shadow-none hover:border-0 focus-visible:border-0"
      >
        {#snippet prefix()}
          <FunnelSimpleIcon size={12} weight="bold" class="text-white/62" />
        {/snippet}
      </SelectPicker>

      <SelectPicker
        items={genreOptions}
        bind:value={selectedGenre}
        triggerClass="h-9 min-w-[132px] rounded-[10px] border-0 bg-muted/60 px-2.5 shadow-none hover:border-0 focus-visible:border-0"
      >
        {#snippet prefix()}
          <FunnelSimpleIcon size={12} weight="bold" class="text-white/62" />
        {/snippet}
      </SelectPicker>
    </div>

    <div class="mt-3 flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-wrap items-center gap-2">
        {#if hasActiveFilters}
          <button
            type="button"
            class="rounded-md bg-red-500/18 px-3 py-1 text-[0.68rem] font-medium text-red-200 transition hover:bg-red-500/28"
            onclick={clearFilters}
          >
            Clear filters
          </button>
        {/if}

        <span class="rounded-md bg-white/[0.06] px-3 py-1 text-[0.68rem] text-white/76">
          {totalResults} results
        </span>
      </div>

      {#if showPagination}
        <div class="ml-auto">
          <Pagination count={paginationCount} bind:page {perPage} siblingCount={1} class="w-auto justify-end">
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
  {#if loading}
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 2xl:grid-cols-8">
      {#each Array.from({ length: perPage }) as _, index (index)}
        <div class="space-y-2">
          <div class="aspect-[2/3] animate-pulse rounded-lg bg-white/[0.06]"></div>
          <div class="h-3 w-[75%] animate-pulse rounded bg-white/[0.06]"></div>
          <div class="h-2.5 w-[45%] animate-pulse rounded bg-white/[0.05]"></div>
        </div>
      {/each}
    </div>
  {:else if error}
    <div class="rounded-xl bg-red-950/35 px-4 py-3 text-sm text-red-200">
      {error}
    </div>
  {:else if results.length === 0}
    <div class="rounded-xl bg-muted/30 px-4 py-12 text-center text-sm font-mono text-white/58">
      No anime matches your current query and filters.
    </div>
  {:else}
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 2xl:grid-cols-8">
      {#each results as anime (anime.id)}
        <CompactAnimeCard {anime} />
      {/each}
    </div>

    {#if showPagination}
      <div class="mt-6">
        <Pagination count={paginationCount} bind:page {perPage} siblingCount={1}>
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
</section>