<script lang="ts" context="module">
    const bgCache = new Map<number, string | null>()
    const bgRequests = new Map<number, Promise<string | null>>()
</script>

<script lang="ts">
    import { PlayIcon, InfoIcon } from 'phosphor-svelte'
    import type { LibraryEntry } from '$lib/types/library'
    import { getTvdbBackground } from '$lib/api/tvdb'

    export let entry: LibraryEntry
    export let episode: number

    let bgImage: string | null = null
    let reqId = 0

    $: if (entry) void loadBg(entry)

    async function loadBg(e: LibraryEntry) {
        const id = ++reqId
        // Immediate fallback so there is always something behind the gradients
        bgImage = e.banner_image ?? e.cover_image ?? null

        if (bgCache.has(e.anilist_id)) {
            if (id === reqId) bgImage = bgCache.get(e.anilist_id) ?? e.banner_image ?? e.cover_image ?? null
            return
        }

        let req = bgRequests.get(e.anilist_id)
        if (!req) {
            req = getTvdbBackground(e.anilist_id, e.format)
                .then(v => v ?? null)
                .catch(() => null)
                .then(v => { bgCache.set(e.anilist_id, v); bgRequests.delete(e.anilist_id); return v })
            bgRequests.set(e.anilist_id, req)
        }

        const resolved = await req
        if (id === reqId) bgImage = resolved ?? e.banner_image ?? e.cover_image ?? null
    }

    $: epText = entry.episode_total
        ? `Episode ${episode} of ${entry.episode_total}`
        : `Episode ${episode}`
</script>

<div
    class="relative w-full overflow-hidden"
    style="height: clamp(460px, 68vh, 860px)"
    aria-label="Continue watching {entry.title}"
    role="region"
>
    <!-- Background -->
    <div class="absolute inset-0">
        <!-- Mobile: cover art -->
        <img
            src={entry.cover_image ?? ''}
            alt={entry.title}
            class="sm:hidden absolute inset-0 z-0 w-full h-full object-cover object-top brightness-40 blur-sm scale-105"
        />
        <!-- sm+: TVDB / AniList landscape background -->
        <img
            src={bgImage ?? entry.banner_image ?? entry.cover_image ?? ''}
            alt={entry.title}
            class="hidden sm:block absolute inset-0 z-0 w-full h-full object-cover scale-110 brightness-50
                   transition-opacity duration-700"
        />
        <div class="pointer-events-none absolute inset-0 z-10 bg-linear-to-r from-black/95 via-black/50 to-transparent"></div>
        <div class="pointer-events-none absolute inset-0 z-10 bg-linear-to-t from-black via-black/10 to-transparent"></div>
    </div>

    <!-- Content -->
    <div class="relative z-20 flex h-full items-end pb-10 px-8">
        <div class="flex flex-col gap-3 min-w-0 max-w-140">

            <!-- Label -->
            <div class="flex items-center gap-2">
                <PlayIcon size={13} weight="fill" class="text-white/50 shrink-0" />
                <span class="text-[0.78rem] font-semibold uppercase tracking-[0.12em] text-white/50">
                    Continue Watching
                </span>
            </div>

            <!-- Anime title -->
            <h2 class="text-[clamp(1.8rem,4.5vw,3.2rem)] font-bold leading-tight line-clamp-2 m-0 text-white">
                {entry.title}
            </h2>

            <!-- Episode info -->
            <p class="m-0 text-white/60 text-[0.9rem] font-medium">{epText}</p>

            <!-- Actions -->
            <div class="flex gap-2 mt-2">
                <a
                    href="/watch/{entry.anilist_id}?ep={episode}"
                    class="inline-flex items-center gap-2 h-10 px-5 rounded-lg
                           bg-white text-black text-[0.85rem] font-semibold
                           no-underline transition-opacity hover:opacity-90"
                >
                    <PlayIcon size={15} weight="fill" />
                    Play Episode {episode}
                </a>
                <a
                    href="/anime/{entry.anilist_id}"
                    class="inline-flex items-center gap-2 h-10 px-4 rounded-lg
                           border border-white/20 bg-white/10 text-white
                           text-[0.85rem] font-medium no-underline
                           transition-colors hover:bg-white/15"
                >
                    <InfoIcon size={14} weight="bold" />
                    <span class="hidden sm:inline">Details</span>
                </a>
            </div>
        </div>
    </div>
</div>
