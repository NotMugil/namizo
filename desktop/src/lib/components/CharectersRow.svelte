<script lang="ts">
    import type { Character } from '$lib/types/anime'
    import { ArrowLeftIcon, ArrowRightIcon } from 'phosphor-svelte'

    export let characters: Character[]

    let railEl: HTMLDivElement | null = null
    let canScrollLeft = false
    let canScrollRight = false

    function updateScrollState() {
        if (!railEl) return
        const maxLeft = railEl.scrollWidth - railEl.clientWidth
        canScrollLeft = railEl.scrollLeft > 3
        canScrollRight = railEl.scrollLeft < maxLeft - 3
    }

    function bindRail(node: HTMLDivElement) {
        railEl = node
        const observer = new ResizeObserver(() => updateScrollState())
        node.addEventListener('scroll', updateScrollState, { passive: true })
        observer.observe(node)
        setTimeout(updateScrollState, 50)
        return {
            destroy: () => {
                node.removeEventListener('scroll', updateScrollState)
                observer.disconnect()
            }
        }
    }

    function scroll(dir: -1 | 1) {
        if (!railEl) return
        railEl.scrollBy({ left: dir * 900, behavior: 'smooth' })
        setTimeout(updateScrollState, 260)
    }
</script>

{#if characters.length}
    <section class="grid gap-3 min-w-0">
        <div class="flex items-center justify-between gap-2">
            <h2 class="section-title">Characters</h2>
            <div class="flex gap-1">
                <button class="chevron-btn" disabled={!canScrollLeft} onclick={() => scroll(-1)}>
                    <ArrowLeftIcon size={14} weight="bold" />
                </button>
                <button class="chevron-btn" disabled={!canScrollRight} onclick={() => scroll(1)}>
                    <ArrowRightIcon size={14} weight="bold" />
                </button>
            </div>
        </div>

        <div
            use:bindRail
            class="grid gap-2 overflow-x-auto overflow-y-hidden
                   [scrollbar-width:none] [&::-webkit-scrollbar]:hidden
                   [grid-template-rows:repeat(2,auto)] [grid-auto-flow:column]
                   [grid-auto-columns:minmax(280px,320px)]
                   scroll-smooth snap-x snap-mandatory"
        >
            {#each characters as character}
                <article class="grid gap-2 rounded-[10px] p-2 min-w-0
                                [grid-template-columns:90px_minmax(0,1fr)] items-center
                                snap-start">
                    <img
                        src={character.image ?? '/favicon.png'}
                        alt={character.name}
                        class="w-20 aspect-square rounded-lg object-cover border border-white/8 shrink-0"
                        loading="lazy"
                    />
                    <div class="min-w-0">
                        <h3 class="m-0 text-[0.86rem] font-medium truncate">{character.name}</h3>
                        <p class="m-0 text-[0.72rem] text-white/45 uppercase tracking-[0.04em]">
                            {character.role}
                        </p>
                    </div>
                </article>
            {/each}
        </div>
    </section>
{/if}