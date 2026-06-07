<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import { toast } from "svelte-sonner";
    import { breadcrumb } from "$lib/state.svelte";
    import { libraryFetch as libraryFetchApi } from "$lib/api/library";
    import {
        BellIcon,
        CalendarBlankIcon,
        CaretDownIcon,
        FunnelSimpleIcon,
        ListIcon,
        MagnifyingGlassIcon,
        SortAscendingIcon,
    } from "phosphor-svelte";
    import AnimeCard from "$lib/components/AnimeCard.svelte";
    import SelectPicker from "$lib/components/ui/select/SelectPicker.svelte";
    import LoadingScreen from "$lib/components/shared/LoadingScreen.svelte";
    import { libraryFacets, libraryFetch } from "$lib/api/library";
    import type {
        KnownLibraryReleaseStatus,
        LibraryEntry,
        LibraryFacets,
        LibraryListScope,
        LibraryReleaseFilter,
        LibrarySortValue,
    } from "$lib/types/library";
    import {
        LIBRARY_BANNER_KEY,
        LIBRARY_CARD_GAP,
        LIBRARY_CARD_WIDTH,
        LIBRARY_DEFAULT_RELEASE_STATUSES,
        LIBRARY_LIST_TYPE_OPTIONS,
        LIBRARY_SECTION_DEFS,
        LIBRARY_SORT_OPTIONS,
    } from "$lib/constants/library";
    import {
        chunkRows,
        buildLibraryReleaseOptions,
        buildLibrarySeasonOptions,
        compareLibraryEntries,
        computeCardsPerRow,
        deriveOptionsFromEntries,
        deriveOptionsFromFacets,
        normalizeGenre,
        selectedLibraryGenreLabel,
        toSummaryFromLibraryEntry,
        withPlaceholders,
    } from "$lib/utils/library-view";
    import { TrashSimpleIcon, ArrowsClockwiseIcon, SpinnerGapIcon } from "phosphor-svelte";

    const listTypeOptions = LIBRARY_LIST_TYPE_OPTIONS;
    const sortOptions = LIBRARY_SORT_OPTIONS;

    export let data: { anilistConnected?: boolean } = {};

    let entries: LibraryEntry[] = [];
    let facets: LibraryFacets | null = null;
    let loading = true;
    let error: string | null = null;
    let showAniListBanner = true;

    let listScope: LibraryListScope = "ALL";
    let query = "";
    let selectedGenres: string[] = [];
    let genreOpen = false;
    let sortValue: LibrarySortValue = "A_Z";
    let formatFilter = "ALL";
    let releaseFilter: LibraryReleaseFilter = "ALL";
    let seasonFilter = "ALL";
    let yearFilter = "ALL";
    let contentWidth = 0;
    let viewportWidth = 0;

    $: genreLabel = selectedLibraryGenreLabel(selectedGenres);

    $: fallbackOptions = deriveOptionsFromEntries(entries);
    $: facetOptions = deriveOptionsFromFacets(facets);

    $: availableGenres =
        facetOptions.genres.length > 0
            ? facetOptions.genres
            : fallbackOptions.genres;
    $: availableFormats = fallbackOptions.formats;
    $: availableSeasons =
        facetOptions.seasons.length > 0
            ? facetOptions.seasons
            : fallbackOptions.seasons;
    $: availableYears =
        facetOptions.years.length > 0
            ? facetOptions.years
            : fallbackOptions.years;
    $: availableReleaseStatuses = (
        facetOptions.releaseStatuses.length > 0
            ? facetOptions.releaseStatuses
            : fallbackOptions.releaseStatuses.length > 0
              ? fallbackOptions.releaseStatuses
              : LIBRARY_DEFAULT_RELEASE_STATUSES
    ) as KnownLibraryReleaseStatus[];

    $: filtersActive =
        query.trim().length > 0 ||
        formatFilter !== "ALL" ||
        releaseFilter !== "ALL" ||
        seasonFilter !== "ALL" ||
        yearFilter !== "ALL" ||
        selectedGenres.length > 0;

    $: clearIconClass = filtersActive
        ? "rounded-[10px] bg-red-400/20 p-2 text-red-100 transition hover:bg-red-400/30"
        : "rounded-[10px] bg-white/10 p-2 text-white/70 transition hover:bg-white/20";

    $: if (
        releaseFilter !== "ALL" &&
        !availableReleaseStatuses.includes(
            releaseFilter as KnownLibraryReleaseStatus,
        )
    ) {
        releaseFilter = "ALL";
    }
    $: if (seasonFilter !== "ALL" && !availableSeasons.includes(seasonFilter)) {
        seasonFilter = "ALL";
    }
    $: if (
        yearFilter !== "ALL" &&
        !availableYears.includes(Number(yearFilter))
    ) {
        yearFilter = "ALL";
    }
    $: selectedGenres = selectedGenres.filter((genre) =>
        availableGenres.includes(genre),
    );

    $: cardsPerRow = computeCardsPerRow(
        contentWidth,
        viewportWidth,
        LIBRARY_CARD_WIDTH,
        LIBRARY_CARD_GAP,
    );

    $: listScoped =
        listScope === "ALL"
            ? entries
            : entries.filter((entry) => entry.status === listScope);

    $: searched =
        query.trim().length === 0
            ? listScoped
            : listScoped.filter((entry) =>
                  entry.title
                      .toLowerCase()
                      .includes(query.trim().toLowerCase()),
              );

    $: filtered = searched.filter((entry) => {
        if (selectedGenres.length > 0) {
            const entryGenres = new Set(
                (entry.genres ?? [])
                    .map((genre) => normalizeGenre(genre))
                    .filter((genre) => genre.length > 0),
            );
            const selectedGenreKeys = selectedGenres
                .map((genre) => normalizeGenre(genre))
                .filter((genre) => genre.length > 0);
            if (!selectedGenreKeys.every((genre) => entryGenres.has(genre))) {
                return false;
            }
        }

        if (
            formatFilter !== "ALL" &&
            (entry.format ?? "").toUpperCase() !== formatFilter
        ) {
            return false;
        }

        if (
            releaseFilter !== "ALL" &&
            (entry.anilist_status ?? "").toUpperCase() !== releaseFilter
        ) {
            return false;
        }

        if (
            seasonFilter !== "ALL" &&
            (entry.season ?? "").toUpperCase() !== seasonFilter
        ) {
            return false;
        }

        if (yearFilter !== "ALL" && entry.season_year !== Number(yearFilter)) {
            return false;
        }

        return true;
    });

    $: sorted = [...filtered].sort((left, right) =>
        compareLibraryEntries(left, right, sortValue),
    );

    $: sections = LIBRARY_SECTION_DEFS.map((section) => {
        const items = sorted.filter((entry) => entry.status === section.value);
        return {
            ...section,
            rows: chunkRows(items, cardsPerRow).map((row) =>
                withPlaceholders(row, cardsPerRow),
            ),
            count: items.length,
        };
    }).filter((section) => section.count > 0);

    $: releaseOptions = buildLibraryReleaseOptions(availableReleaseStatuses);
    $: seasonOptions = buildLibrarySeasonOptions(availableSeasons);

    async function loadLibraryData() {
        loading = true;
        error = null;

        const [entriesResult, facetsResult] = await Promise.allSettled([
            libraryFetch(),
            libraryFacets(),
        ]);

        if (entriesResult.status === "fulfilled") {
            entries = entriesResult.value;
        } else {
            error = String(entriesResult.reason);
            loading = false;
            return;
        }

        facets =
            facetsResult.status === "fulfilled" ? facetsResult.value : null;
        loading = false;
    }

    function dismissAniListBanner() {
        showAniListBanner = false;
        try {
            localStorage.setItem(LIBRARY_BANNER_KEY, "1");
        } catch {
            // best effort only
        }
    }

    function clearFilters() {
        query = "";
        selectedGenres = [];
        formatFilter = "ALL";
        releaseFilter = "ALL";
        seasonFilter = "ALL";
        yearFilter = "ALL";
    }

    function toggleGenre(genre: string) {
        if (selectedGenres.includes(genre)) {
            selectedGenres = selectedGenres.filter((value) => value !== genre);
        } else {
            selectedGenres = [...selectedGenres, genre];
        }
    }

    function clearGenres() {
        selectedGenres = [];
    }

    // ── Section expand/collapse ─────────────────────────────────────────────
    let expandedSections: Set<string> = new Set();
    function toggleSection(value: string) {
        if (expandedSections.has(value)) expandedSections.delete(value);
        else expandedSections.add(value);
        expandedSections = new Set(expandedSections);
    }

    // ── Scroll-reveal filter bar ────────────────────────────────────────────
    let filterVisible = true;
    let lastScrollY = 0;
    let syncingCloud = false;

    function handleScroll() {
        const y = window.scrollY;
        const dir = y > lastScrollY ? "down" : "up";
        if (dir === "down" && y > 80) filterVisible = false;
        if (dir === "up") filterVisible = true;
        lastScrollY = y;
    }

    onMount(async () => {
        breadcrumb.items = [{ label: 'Home', href: '/' }, { label: 'Library' }];
        window.addEventListener("scroll", handleScroll, { passive: true });

        // Auto-dismiss if user already has AniList connected
        if (data.anilistConnected) {
            showAniListBanner = false;
            try { localStorage.setItem(LIBRARY_BANNER_KEY, "1"); } catch {}
        } else {
            try {
                showAniListBanner = localStorage.getItem(LIBRARY_BANNER_KEY) !== "1";
            } catch {
                showAniListBanner = true;
            }
        }
        await loadLibraryData();
    });

    onDestroy(() => {
        breadcrumb.items = [];
        window.removeEventListener("scroll", handleScroll);
    });

    // ── Cloud sync ──────────────────────────────────────────────────────────
    async function syncToCloud() {
        syncingCloud = true;
        try {
            const allEntries = await libraryFetchApi();
            const res = await fetch("/api/library/push", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ entries: allEntries })
            });
            if (!res.ok) throw new Error(await res.text());
            const { pushed } = await res.json();
            toast.success(`Synced ${pushed} entries to cloud`);
        } catch {
            toast.error("Cloud sync failed. Try again.");
        } finally {
            syncingCloud = false;
        }
    }
</script>

<svelte:window
    bind:innerWidth={viewportWidth}
    on:click={() => (genreOpen = false)}
/>

{#if loading}
    <LoadingScreen
        label="Loading library..."
        fullscreen={false}
        className="min-h-[70vh]"
    />
{:else if error}
    <p class="px-8 pt-24 text-center text-red-400">{error}</p>
{:else}
    <!-- Sticky scroll-reveal filter bar -->
    <div class="sticky top-14 z-30 transition-transform duration-300 bg-black/90 backdrop-blur-md border-b border-white/6
         {filterVisible ? 'translate-y-0' : '-translate-y-full'}">
        <div class="w-full px-8 md:px-10 lg:px-12 py-3 space-y-2.5">
            <!-- Row 1: scope + search + clear + sync -->
            <div class="flex items-center justify-between gap-3">
                <div class="grid gap-3 flex-1 md:grid-cols-[220px_minmax(0,1fr)]">
                    <SelectPicker items={listTypeOptions} bind:value={listScope} />
                    <div class="flex items-center gap-2">
                        <label class="relative flex-1">
                            <MagnifyingGlassIcon
                                size={14}
                                class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-white/45"
                            />
                            <input
                                type="search"
                                placeholder="Search titles"
                                bind:value={query}
                                class="h-9 w-full rounded-[10px] border border-white/12 bg-black/62 pl-10 pr-3 text-sm text-white/90 outline-none placeholder:text-white/45"
                            />
                        </label>
                        <button type="button" class={clearIconClass} onclick={clearFilters} aria-label="Reset filters">
                            <TrashSimpleIcon size={16} weight="fill" />
                        </button>
                    </div>
                </div>
                <button type="button" onclick={syncToCloud} disabled={syncingCloud}
                    class="shrink-0 inline-flex items-center gap-1.5 rounded-[10px] border border-white/12 bg-white/5
                           h-9 px-3 text-[0.8rem] text-white/55 hover:bg-white/10 hover:text-white transition-colors disabled:opacity-40"
                    title="Sync library to cloud">
                    {#if syncingCloud}
                        <SpinnerGapIcon size={14} class="animate-spin" />
                    {:else}
                        <ArrowsClockwiseIcon size={14} />
                    {/if}
                    <span class="hidden sm:inline">Sync</span>
                </button>
            </div>

            <!-- Row 2: genre, sort, format, release, season, year -->
            <div class="grid gap-2 xl:grid-cols-[minmax(190px,240px)_minmax(190px,1fr)_170px_190px_160px_140px]">
                <div class="relative">
                    <button
                        type="button"
                        class="inline-flex h-9 w-full items-center justify-between gap-2 rounded-[10px] border border-white/12 bg-black/62 px-3 text-sm text-white/86 backdrop-blur-lg"
                        onclick={(event) => { event.stopPropagation(); genreOpen = !genreOpen; }}
                    >
                        <span class="inline-flex min-w-0 items-center gap-1.5">
                            <FunnelSimpleIcon size={13} class="text-white/62" />
                            <span class="truncate">{genreLabel}</span>
                        </span>
                        <CaretDownIcon size={12} weight="bold" class="text-white/58" />
                    </button>
                    {#if genreOpen}
                        <div class="absolute z-90 mt-2 max-h-64 w-full overflow-y-auto rounded-[10px] border border-white/14 bg-black/72 p-1 text-white shadow-[0_16px_42px_rgba(0,0,0,0.62)] backdrop-blur-[22px]">
                            <button type="button"
                                class="mb-1 h-8 w-full rounded-[7px] px-2 text-left text-[0.82rem] text-white/80 transition hover:bg-white/10 hover:text-white"
                                onclick={(event) => { event.stopPropagation(); clearGenres(); }}>
                                Clear genres
                            </button>
                            {#each availableGenres as genre}
                                <button type="button"
                                    class="flex h-8 w-full items-center justify-between rounded-[7px] px-2 text-left text-[0.82rem] text-white/78 transition hover:bg-white/10 hover:text-white"
                                    onclick={(event) => { event.stopPropagation(); toggleGenre(genre); }}>
                                    <span class="truncate">{genre}</span>
                                    <span class={selectedGenres.includes(genre) ? "text-white/90" : "text-transparent"}>Selected</span>
                                </button>
                            {/each}
                        </div>
                    {/if}
                </div>

                <SelectPicker items={sortOptions} bind:value={sortValue}>
                    {#snippet prefix()}<SortAscendingIcon size={13} class="text-white/62" />{/snippet}
                </SelectPicker>

                <SelectPicker items={[{ value: "ALL", label: "All Formats" }, ...availableFormats.map(v => ({ value: v.toUpperCase(), label: v }))]} bind:value={formatFilter}>
                    {#snippet prefix()}<ListIcon size={13} class="text-white/62" />{/snippet}
                </SelectPicker>

                <SelectPicker items={releaseOptions} bind:value={releaseFilter}>
                    {#snippet prefix()}<BellIcon size={13} class="text-white/62" />{/snippet}
                </SelectPicker>

                <SelectPicker items={seasonOptions} bind:value={seasonFilter}>
                    {#snippet prefix()}<CalendarBlankIcon size={13} class="text-white/62" />{/snippet}
                </SelectPicker>

                <SelectPicker items={[{ value: "ALL", label: "All Years" }, ...availableYears.map(v => ({ value: String(v), label: String(v) }))]} bind:value={yearFilter}>
                    {#snippet prefix()}<CalendarBlankIcon size={13} class="text-white/62" />{/snippet}
                </SelectPicker>
            </div>
        </div>
    </div>

    <main
        bind:clientWidth={contentWidth}
        class="w-full space-y-8 px-8 pb-14 pt-4 md:px-10 lg:px-12"
    >
        {#if showAniListBanner}
            <section
                class="flex flex-wrap items-center justify-between gap-3 rounded-lg bg-white/4 px-4 py-3"
            >
                <p class="text-sm text-white/80">
                    Connect AniList to sync across devices.
                </p>
                <button
                    type="button"
                    class="rounded-md bg-white/10 px-3 py-1.5 text-xs uppercase tracking-[0.06em] text-white/75 transition-colors hover:bg-white/16"
                    onclick={dismissAniListBanner}
                >
                    Dismiss
                </button>
            </section>
        {/if}

        {#if sections.length === 0}
            <section
                class="rounded-lg bg-white/3 p-4 text-sm text-white/55"
            >
                No titles found for the current filters.
            </section>
        {:else}
            <section class="space-y-8">
                {#each sections as section}
                    {@const expanded = expandedSections.has(section.value)}
                    {@const visibleRows = expanded ? section.rows : section.rows.slice(0, 2)}
                    {@const hiddenCount = Math.max(0, section.rows.length - 2) * cardsPerRow}
                    <div class="space-y-3">
                        <div class="flex items-baseline gap-2.5 py-2">
                            <span class="w-2 h-2 rounded-full shrink-0 self-center {section.dotClass}"></span>
                            <h2 class="text-lg font-semibold text-white/92 md:text-xl">
                                {section.label}
                            </h2>
                            <span class="text-sm font-medium text-white/40 tabular-nums">
                                {section.count}
                            </span>
                        </div>

                        <div class="space-y-3">
                            {#each visibleRows as row}
                                <div
                                    class="grid justify-start gap-6 px-1 pb-1"
                                    style={`grid-template-columns: repeat(${cardsPerRow}, ${LIBRARY_CARD_WIDTH}px);`}
                                >
                                    {#each row as entry}
                                        {#if entry}
                                            <AnimeCard
                                                anime={toSummaryFromLibraryEntry(entry)}
                                                listStatus={entry.status}
                                            />
                                        {:else}
                                            <div
                                                class="pointer-events-none invisible"
                                                aria-hidden="true"
                                                style={`width:${LIBRARY_CARD_WIDTH}px`}
                                            ></div>
                                        {/if}
                                    {/each}
                                </div>
                            {/each}
                        </div>

                        {#if section.rows.length > 2}
                            <div class="flex justify-center pt-1">
                                <button
                                    type="button"
                                    onclick={() => toggleSection(section.value)}
                                    class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/4
                                           px-5 py-2 text-xs font-medium text-white/50
                                           hover:border-white/20 hover:bg-white/8 hover:text-white/80 transition-colors"
                                >
                                    <svg width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"
                                        viewBox="0 0 24 24"
                                        class="transition-transform duration-200 {expanded ? 'rotate-180' : ''}">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                                    </svg>
                                    {expanded ? 'Show less' : `Show ${hiddenCount} more`}
                                </button>
                            </div>
                        {/if}
                    </div>
                {/each}
            </section>
        {/if}
    </main>
{/if}