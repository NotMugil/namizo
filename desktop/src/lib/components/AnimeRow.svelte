<script lang="ts">
    import type { AnimeSummary } from "$lib/types/anime";
    import AnimeCard from "./AnimeCard.svelte";
    import { ArrowLeftIcon, ArrowRightIcon } from "phosphor-svelte";

    export let title: string;
    export let items: AnimeSummary[];
    export let titleClass: string = "text-base font-semibold"

    let scrollContainer: HTMLDivElement
    let canScrollLeft = false
    let canScrollRight = false

    function updateScrollState() {
        if (!scrollContainer) return
        const maxLeft = scrollContainer.scrollWidth - scrollContainer.clientWidth
        canScrollLeft = scrollContainer.scrollLeft > 3
        canScrollRight = scrollContainer.scrollLeft < maxLeft - 3
    }

    function bindScroll(node: HTMLDivElement) {
        scrollContainer = node
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

    function scroll(direction: "left" | "right") {
        scrollContainer.scrollBy({
            left: direction === "right" ? 1000 : -1000,
            behavior: "smooth",
        })
        setTimeout(updateScrollState, 260)
    }

    $: if (items && scrollContainer) {
        scrollContainer.scrollLeft = 0
        updateScrollState()
    }
</script>

<section class="mb-8">
    <div class="flex items-center justify-between mb-4">
        <h2 class={titleClass}>{title}</h2>
        <div class="flex gap-1">
            <button
                class="chevron-btn"
                disabled={!canScrollLeft}
                on:click={() => scroll("left")}
            >
                <ArrowLeftIcon size={14} weight="bold" />
            </button>
            <button
                class="chevron-btn"
                disabled={!canScrollRight}
                on:click={() => scroll("right")}
            >
                <ArrowRightIcon size={14} weight="bold" />
            </button>
        </div>
    </div>

    <div
        use:bindScroll
        class="flex gap-3 overflow-x-auto pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden scroll-smooth snap-x snap-mandatory"
    >
        {#each items as anime (anime.id)}
            <div class="snap-start">
                <AnimeCard {anime} />
            </div>
        {/each}
    </div>
</section>