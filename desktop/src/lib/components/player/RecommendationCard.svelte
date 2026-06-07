<script lang="ts" context="module">
    const bgCache = new Map<string, string | null>();
    const bgRequests = new Map<string, Promise<string | null>>();
</script>

<script lang="ts">
    import { onMount } from 'svelte';
    import { getTvdbBackground } from '$lib/api/tvdb';
    import { throttledApiCall } from '$lib/utils/request-limiter';
    import type { AnimeSummary } from '$lib/types/anime';

    export let rec: AnimeSummary;

    let bgImage: string | null = null;

    function key(r: AnimeSummary): string {
        return `${r.id}|${(r.format ?? '').toUpperCase()}`;
    }

    function formatMeta(r: AnimeSummary): string {
        const parts: string[] = [];
        if (r.format) parts.push(r.format);
        if (r.season_year) parts.push(String(r.season_year));
        const isMovie = (r.format ?? '').toUpperCase() === 'MOVIE';
        if (isMovie && r.duration) {
            const h = Math.floor(r.duration / 60);
            const m = r.duration % 60;
            parts.push(h > 0 ? `${h}h${m ? ` ${m}m` : ''}` : `${m}m`);
        } else if (r.episodes) {
            parts.push(`${r.episodes} ep${r.episodes !== 1 ? 's' : ''}`);
        }
        return parts.join(' · ');
    }

    onMount(async () => {
        const k = key(rec);
        const cached = bgCache.get(k);
        if (cached !== undefined) { bgImage = cached; return; }

        let inFlight = bgRequests.get(k);
        if (!inFlight) {
            inFlight = throttledApiCall(() => getTvdbBackground(rec.id, rec.format))
                .then(v => v ?? null)
                .catch(() => null)
                .then(v => { bgCache.set(k, v); bgRequests.delete(k); return v; });
            bgRequests.set(k, inFlight);
        }
        bgImage = await inFlight;
    });

    $: isAiring   = (rec.status ?? '').toUpperCase() === 'RELEASING';
    $: isUpcoming = (rec.status ?? '').toUpperCase() === 'NOT_YET_RELEASED';
    $: isHiatus   = (rec.status ?? '').toUpperCase() === 'HIATUS';
    $: meta = formatMeta(rec);
</script>

<a
    href="/anime/{rec.id}"
    class="group relative flex h-28 sm:h-32 overflow-hidden rounded-lg no-underline"
>
    <!-- TVDB banner (or cover blurred as fallback) -->
    {#if bgImage}
        <img
            src={bgImage}
            alt=""
            class="pointer-events-none absolute inset-0 h-full w-full object-cover opacity-55 transition-transform duration-500 group-hover:scale-105"
            loading="lazy"
        />
    {:else if rec.cover_image}
        <img
            src={rec.cover_image}
            alt=""
            class="pointer-events-none absolute inset-0 h-full w-full object-cover scale-110 blur-sm opacity-20"
            loading="lazy"
        />
    {:else}
        <div class="absolute inset-0 bg-[#0d1117]"></div>
    {/if}

    <!-- Left-to-right gradient so the poster and text are legible -->
    <div class="pointer-events-none absolute inset-0 bg-linear-to-r from-black/80 via-black/55 to-transparent"></div>

    <!-- Content row -->
    <div class="relative z-10 flex h-full w-full items-center gap-3.5 px-3 py-2.5">
        <!-- Portrait poster -->
        <div class="h-full shrink-0 aspect-2/3 overflow-hidden rounded-md border border-white/12">
            <img
                src={rec.cover_image}
                alt={rec.title}
                class="h-full w-full object-cover"
                loading="lazy"
            />
        </div>

        <!-- Meta text -->
        <div class="flex min-w-0 flex-1 flex-col gap-1.5">
            <p class="text-[15px] font-semibold text-white leading-snug line-clamp-2 transition-colors group-hover:text-white/85">
                {rec.title}
            </p>

            {#if meta}
                <p class="text-[13px] text-white/45">{meta}</p>
            {/if}

            <!-- Status + score -->
            <div class="flex items-center gap-2 flex-wrap">
                {#if isAiring}
                    <span class="inline-flex items-center gap-1 rounded-full bg-emerald-500/15 border border-emerald-500/25 px-2 py-0.5 text-[11px] font-medium text-emerald-300">
                        <span class="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                        Airing
                    </span>
                {:else if isUpcoming}
                    <span class="rounded-full bg-blue-500/15 border border-blue-500/25 px-2 py-0.5 text-[11px] font-medium text-blue-300">Upcoming</span>
                {:else if isHiatus}
                    <span class="rounded-full bg-amber-500/15 border border-amber-500/25 px-2 py-0.5 text-[11px] font-medium text-amber-300">Hiatus</span>
                {/if}
                {#if rec.average_score}
                    <span class="text-[12px] text-white/35">★ {(rec.average_score / 10).toFixed(1)}</span>
                {/if}
            </div>
        </div>
    </div>
</a>
