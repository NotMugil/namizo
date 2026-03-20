<script lang="ts">
    import { onMount, onDestroy } from 'svelte'
    import { goto } from '$app/navigation'
    import { PlayIcon, InfoIcon, ArrowLeftIcon, ArrowRightIcon } from 'phosphor-svelte'
    import type { AnimeSummary } from '$lib/types/anime'

    export let items: AnimeSummary[] = []

    let current = 0
    let timer: ReturnType<typeof setInterval> | null = null
    let paused = false

    $: item = items[current] ?? null
    $: totalItems = Math.min(items.length, 8) // cap at 8 for carousel

    function next() {
        current = (current + 1) % totalItems
    }

    function prev() {
        current = (current - 1 + totalItems) % totalItems
    }

    function goTo(index: number) {
        current = index
        resetTimer()
    }

    function resetTimer() {
        if (timer) clearInterval(timer)
        if (!paused) {
            timer = setInterval(next, 5000)
        }
    }

    onMount(() => {
        timer = setInterval(next, 5000)
    })

    onDestroy(() => {
        if (timer) clearInterval(timer)
    })

    function formatScore(score: number | null): string {
        if (!score) return ''
        return (score / 10).toFixed(1)
    }
</script>

{#if item}
    <div
        class="relative w-full overflow-hidden"
        style="height: clamp(400px, 60vh, 780px)"
        aria-label="Featured anime carousel"
        onmouseenter={() => { paused = true; if (timer) clearInterval(timer) }}
        onmouseleave={() => { paused = false; resetTimer() }}
    >
        <!-- Background image -->
        <div class="absolute inset-0">
            <img
                src={item.banner_image ?? item.cover_image}
                alt={item.title}
                class="w-full h-full object-cover scale-110 brightness-50"
            />
            <div class="absolute inset-0 bg-gradient-to-r from-black/90 via-black/40 to-transparent"></div>
            <div class="absolute inset-0 bg-gradient-to-t from-black via-background/20 to-transparent"></div>
        </div>

        <div class="relative z-10 flex h-full items-end pb-8 px-8 gap-6">

            <!-- Cover -->
            <img
                src={item.cover_image}
                alt={item.title}
                class="hidden sm:block md: h-[200px] lg:h-[300px] aspect-[2/3] object-cover rounded-lg
                       border border-white/10 shadow-xl shrink-0 self-end"
            />

            <div class="flex flex-col gap-2 min-w-0 max-w-[520px]">
                <div class="flex gap-1.5 flex-wrap">
                    {#if item.format}
                        <span class="chip">{item.format}</span>
                    {/if}
                    {#if item.average_score}
                        <span class="chip">★ {formatScore(item.average_score)}</span>
                    {/if}
                    {#if item.episodes}
                        <span class="chip">{item.episodes} EPS</span>
                    {/if}
                    {#each item.genres.slice(0, 2) as genre}
                        <span class="chip">{genre}</span>
                    {/each}
                </div>

                <!-- Title -->
                <h2 class="text-[clamp(1.3rem,3vw,2rem)] font-bold leading-tight line-clamp-2 m-0">
                    {item.title}
                </h2>

                {#if item.description}
                    <p class="m-0 text-white/60 text-[0.82rem] leading-[1.5] max-w-[520px]
                            overflow-y-auto [max-height:calc(1.5em*3)]
                            [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
                        {@html item.description}
                    </p>
                {/if}

                <!-- Actions -->
                <div class="flex gap-2 mt-1">
                    <a
                        href="/watch/{item.id}?ep=1"
                        class="inline-flex items-center gap-1.5 h-9 px-4 rounded-lg
                               bg-white text-black text-[0.82rem] font-semibold
                               no-underline transition-opacity hover:opacity-90"
                    >
                        <PlayIcon size={14} weight="fill" />
                        Watch Now
                    </a>
                    <a
                        href="/anime/{item.id}"
                        class="inline-flex items-center gap-1.5 h-9 px-4 rounded-lg
                               border border-white/20 bg-white/10 text-white
                               text-[0.82rem] font-medium no-underline
                               transition-colors hover:bg-white/15"
                    >
                        <InfoIcon size={14} weight="bold" />
                        Details
                    </a>
                </div>
            </div>
        </div>

        <div class="absolute bottom-3 right-6 z-10 flex flex-col items-end gap-3">
            <div class="flex gap-1">
                <button class="chevron-btn" onclick={prev} aria-label="Previous">
                    <ArrowLeftIcon size={14} weight="bold" />
                </button>
                <button class="chevron-btn" onclick={next} aria-label="Next">
                    <ArrowRightIcon size={14} weight="bold" />
                </button>
            </div>

            <div class="flex gap-1.5">
                {#each Array.from({ length: totalItems }) as _, i}
                    <button
                        class="h-1.5 rounded-full transition-all duration-300 border-0
                            {i === current ? 'w-5 bg-white' : 'w-1.5 bg-white/35 hover:bg-white/55'}"
                        onclick={() => goTo(i)}
                        aria-label="Go to slide {i + 1}"
                    ></button>
                {/each}
            </div>
        </div>
    </div>
{/if}