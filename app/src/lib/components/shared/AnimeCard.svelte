<script lang="ts" context="module">
    const getHoverBackgroundCache = new Map<string, string | null>();
    const hoverBackgroundRequests = new Map<string, Promise<string | null>>();
</script>

<script lang="ts">
    import { getTvdbBackground } from "$lib/api/tvdb";
    import type { AnimeSummary } from "$lib/types/anime";
    import type { LibraryEntry, LibraryState } from "$lib/types/library";
    import { goto } from "$app/navigation";
    import { BroadcastIcon, HeartIcon, PencilSimpleIcon, PlayIcon } from "phosphor-svelte";
    import TrailerSurface from "./TrailerSurface.svelte";
    import LibraryEntryEditor from "$lib/components/library/LibraryEntryEditor.svelte";
    import {
        cacheLibraryEntry,
        draftLibraryFromSummary,
        getLibraryStatus,
        resolveLibraryEntry,
    } from "$lib/utils/library";
    import { libraryVersion, playbackPrefs } from "$lib/state.svelte";
    import { throttledApiCall } from "$lib/utils/request-limiter";

    export let anime: AnimeSummary;
    export let listStatus: LibraryState | string | null = null;
    export let fluid = false;

    let favorited = false;
    let hoverActive = false;
    let hoverTimer: ReturnType<typeof setTimeout> | null = null;
    let editorOpen = false;
    let selectedEntry: LibraryEntry | null = null;
    let hoverBackgroundImage: string | null = null;
    let resolvedListStatus: string | null = null;
    let statusLookupVersion = 0;

    $: effectiveStatus = listStatus ?? resolvedListStatus;
    $: statusLabel = formatStatusLabel(effectiveStatus);
    $: isCurrentlyAiring = (anime.status ?? "").trim().toUpperCase() === "RELEASING";
    $: isMovie = (anime.format ?? "").trim().toUpperCase() === "MOVIE";
    $: durationLabel = buildDurationLabel(anime.duration ?? null);

    function buildDurationLabel(minutes: number | null): string | null {
        if (!minutes) return null;
        if (minutes < 60) return `${minutes}m`;
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        return m > 0 ? `${h}h ${m}m` : `${h}h`;
    }
    $: hoverPreviewImage = hoverBackgroundImage ?? anime.banner_image ?? anime.cover_image;
    $: nextAiringLabel = buildNextAiringLabel(
        anime.next_airing_episode ?? null,
        anime.next_airing_at ?? null,
    );

    function onHoverStart() {
        void resolveHoverBackground();
        hoverTimer = setTimeout(() => {
            hoverActive = true;
        }, 800);
    }

    function onHoverEnd() {
        if (hoverTimer) clearTimeout(hoverTimer);
        hoverActive = false;
    }

    async function resolveHoverBackground() {
        const format = (anime.format ?? "").trim().toUpperCase();
        const key = `${anime.id}|${format}`;
        const cached = getHoverBackgroundCache.get(key);
        if (cached !== undefined) {
            hoverBackgroundImage = cached;
            return;
        }

        let inFlight = hoverBackgroundRequests.get(key);
        if (!inFlight) {
            inFlight = throttledApiCall(() => getTvdbBackground(anime.id, anime.format ?? null))
                .then((value) => value ?? null)
                .catch(() => null)
                .then((value) => {
                    getHoverBackgroundCache.set(key, value);
                    hoverBackgroundRequests.delete(key);
                    return value;
                });
            hoverBackgroundRequests.set(key, inFlight);
        }

        hoverBackgroundImage = await inFlight;
    }

    $: if (anime?.id) {
        // Track libraryVersion so this block re-runs after a sync invalidates the cache
        void libraryVersion.n;
        if (listStatus) {
            resolvedListStatus = listStatus;
        } else {
            void resolveListStatus(anime.id);
        }
    }

    async function resolveListStatus(anilistId: number) {
        const lookupVersion = ++statusLookupVersion;
        try {
            const status = await getLibraryStatus(anilistId);
            if (lookupVersion !== statusLookupVersion || anime.id !== anilistId) return;
            resolvedListStatus = status;
        } catch {
            if (lookupVersion !== statusLookupVersion || anime.id !== anilistId) return;
            resolvedListStatus = null;
        }
    }

    async function openCollectionEditor(event: MouseEvent) {
        event.preventDefault();
        event.stopPropagation();

        const fallback = draftLibraryFromSummary(anime);
        try {
            selectedEntry = await resolveLibraryEntry(fallback);
        } catch {
            selectedEntry = fallback;
        }
        editorOpen = true;
    }

    function onEditorSaved(event: CustomEvent<LibraryEntry>) {
        selectedEntry = event.detail;
        resolvedListStatus = event.detail.status;
        cacheLibraryEntry(event.detail);
        editorOpen = false;
    }

    function formatStatusLabel(value: string | null | undefined): string {
        if (!value) return "NOT IN LIST";
        const normalized = value.trim().toUpperCase();
        if (!normalized) return "NOT IN LIST";
        return normalized.replace(/_/g, " ");
    }

    function buildNextAiringLabel(episode: number | null, airingAt: number | null): string | null {
        if (!episode || !airingAt) return null;

        const now = Math.floor(Date.now() / 1000);
        const remaining = airingAt - now;

        if (remaining <= 0) {
            return `Episode ${episode} airing soon`;
        }

        const days = Math.ceil(remaining / 86_400);
        return `Episode ${episode} in ${days} day${days === 1 ? "" : "s"}`;
    }
</script>

<div
    class={`group relative flex ${fluid ? "min-w-0 w-full" : "w-38 sm:w-40 md:w-50 shrink-0"} flex-col rounded-xl text-inherit no-underline`}
    role="link"
    tabindex="0"
    onmouseenter={onHoverStart}
    onmouseleave={onHoverEnd}
    onclick={() => goto(`/anime/${anime.id}`)}
    onkeydown={(e) => e.key === "Enter" && goto(`/anime/${anime.id}`)}
>
    <div
        class="relative w-full overflow-hidden rounded-xl border border-white/8 bg-[#0d1420] aspect-2/3
        transition-[box-shadow,border-color,filter] duration-150
        sm:group-hover:shadow-[0_18px_32px_rgba(3,5,8,0.56)] sm:group-hover:filter-[saturate(1.04)]"
    >
        <img src={anime.cover_image} alt={anime.title} class="h-full w-full object-cover" loading="lazy" />
        {#if isCurrentlyAiring}
            <div class="pointer-events-none absolute left-2 top-2 flex items-center gap-1 rounded-full bg-black/60 backdrop-blur-sm py-1 px-2">
                <BroadcastIcon size={12} weight="fill" class="text-emerald-300" />
                <span class="text-[10px] font-medium text-emerald-200/90">Airing</span>
            </div>
        {/if}
    </div>

    <div class="px-0.5 pt-1.5">
        <p class="m-0 line-clamp-2 text-[14px] leading-snug">{anime.title}</p>
        <p class="mt-0.5 text-[12px] opacity-60">
            {anime.format ?? ""}
            {#if isMovie && durationLabel} · {durationLabel}{:else if anime.episodes} · {anime.episodes} eps{/if}
        </p>
        <!-- <p class="mt-px text-[11px] uppercase tracking-[0.04em] text-white/55">{statusLabel}</p> -->
    </div>

    <div
        class="pointer-events-none absolute inset-0 hidden sm:flex translate-y-1.5 flex-col items-center justify-start gap-2 overflow-hidden rounded-xl border border-white/10
        bg-[linear-gradient(180deg,rgba(8,10,14,0.62),rgba(7,9,13,0.92))]
        p-2.5 opacity-0 shadow-[0_20px_38px_rgba(2,4,8,0.62)] backdrop-blur-[9px]
        transition-[opacity,transform] duration-150
        group-hover:pointer-events-auto group-hover:translate-y-0 group-hover:opacity-100"
    >
        <div class="relative aspect-video w-full shrink-0 overflow-hidden rounded-md border border-white/8 bg-black/20">
            {#if anime.trailer_id && hoverActive && playbackPrefs.autoplayTrailers}
                <TrailerSurface
                    image={hoverPreviewImage ?? anime.cover_image ?? ""}
                    trailerId={anime.trailer_id}
                />
            {:else}
                <img
                    src={hoverPreviewImage ?? anime.cover_image}
                    alt={anime.title}
                    class="h-full w-full object-cover"
                />
            {/if}
        </div>

        <div class="flex flex-col items-center gap-0.5 text-center">
            <p class="m-0 line-clamp-2 text-[14px] leading-snug text-white">{anime.title}</p>
            <p class="m-0 text-[11px] uppercase text-white/50">
                {anime.format ?? ""}
                {#if isMovie && durationLabel} · {durationLabel}{:else if anime.episodes} · {anime.episodes} eps{/if}
            </p>
        </div>
        
        {#if isCurrentlyAiring && nextAiringLabel}
            <p class="m-0 text-[11px] font-medium text-emerald-200/85">{nextAiringLabel}</p>
        {/if}
        <a
            href="/watch/{anime.id}?ep=1"
            class="inline-flex h-8 w-full items-center justify-center gap-1 rounded-md border border-white/20 bg-white/40 px-2.5 py-5 text-[0.81rem] text-white transition-colors hover:bg-white/35"
            onclick={(e) => e.stopPropagation()}
        >
            <PlayIcon size={13} weight="fill" />
            <span>Watch</span>
        </a>
        <p class="m-1 text-[11px] uppercase tracking-[0.04em] text-white/58">{statusLabel}</p>
        
        <div class="mt-auto flex items-center justify-center gap-2">
            <button
                class="inline-flex size-8 items-center justify-center rounded-lg border border-white/15 bg-white/10 text-white transition-colors hover:border-white/30"
                onclick={openCollectionEditor}
                aria-label="Edit planning state"
            >
                <PencilSimpleIcon size={13} weight="bold" />
            </button>
            <button
                class="inline-flex size-8 items-center justify-center rounded-lg border border-white/15 bg-white/10 text-white transition-colors hover:border-white/30"
                onclick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    favorited = !favorited;
                }}
                aria-label="Favorite"
            >
                <HeartIcon size={13} weight={favorited ? "fill" : "regular"} />
            </button>
        </div>
    </div>
</div>

<LibraryEntryEditor bind:open={editorOpen} entry={selectedEntry} on:saved={onEditorSaved} />