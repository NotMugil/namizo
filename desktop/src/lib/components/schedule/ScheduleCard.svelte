<script lang="ts" context="module">
    const bgCache = new Map<string, string | null>();
    const bgRequests = new Map<string, Promise<string | null>>();
</script>

<script lang="ts">
    import { onMount } from 'svelte';
    import { getTvdbBackground } from '$lib/api/tvdb';
    import { throttledApiCall } from '$lib/utils/request-limiter';
    import type { ScheduleEntry } from '../../routes/(app)/schedule/+page.server';

    export let entry: ScheduleEntry;
    export let isTracked: boolean = false;

    let bgImage: string | null = null;
    let loaded = false;

    function cacheKey(e: ScheduleEntry): string {
        return `${e.media.id}|${(e.media.format ?? '').toUpperCase()}`;
    }

    function formatTime(unix: number): string {
        return new Date(unix * 1000).toLocaleTimeString(undefined, {
            hour: 'numeric',
            minute: '2-digit'
        });
    }

    onMount(async () => {
        const key = cacheKey(entry);
        const cached = bgCache.get(key);
        if (cached !== undefined) { bgImage = cached; loaded = true; return; }

        let inFlight = bgRequests.get(key);
        if (!inFlight) {
            inFlight = throttledApiCall(() => getTvdbBackground(entry.media.id, entry.media.format))
                .then(v => v ?? null)
                .catch(() => null)
                .then(v => { bgCache.set(key, v); bgRequests.delete(key); return v; });
            bgRequests.set(key, inFlight);
        }

        bgImage = await inFlight;
        loaded = true;
    });
</script>

<a
    href="/anime/{entry.media.id}"
    class="group relative block overflow-hidden rounded-lg aspect-3/1 no-underline"
>
    <!-- Background image layer -->
    {#if bgImage}
        <img
            src={bgImage}
            alt=""
            class="absolute inset-0 h-full w-full object-cover transition-transform duration-300 group-hover:scale-105
                   {isTracked ? '' : 'grayscale'}"
        />
    {:else}
        <!-- Fallback: blurred cover -->
        <div class="absolute inset-0 bg-[#0b0e17]">
            {#if entry.media.coverImage}
                <img
                    src={entry.media.coverImage}
                    alt=""
                    class="absolute inset-0 h-full w-full object-cover scale-110 blur-sm opacity-20
                           {isTracked ? '' : 'grayscale'}"
                />
            {/if}
        </div>
    {/if}

    <!-- Tracked: subtle blue tint overlay -->
    {#if isTracked}
        <div class="pointer-events-none absolute inset-0 bg-[#02a9ff]/10"></div>
    {/if}

    <!-- Gradient: black at bottom fading to transparent -->
    <div class="pointer-events-none absolute inset-0 bg-linear-to-t from-black/85 via-black/30 to-transparent"></div>

    <!-- Content -->
    <div class="absolute inset-x-0 bottom-0 flex items-end justify-between gap-2 p-2.5">
        <div class="min-w-0">
            <p class="text-[11.5px] font-semibold leading-snug text-white line-clamp-1">
                {entry.media.title}
            </p>
            <p class="mt-0.5 text-[10px] text-white/55">
                Ep {entry.episode} · {formatTime(entry.airingAt)}
            </p>
        </div>
        {#if isTracked}
            <div class="mb-0.5 h-1.5 w-1.5 shrink-0 rounded-full bg-[#02a9ff]"></div>
        {/if}
    </div>
</a>
