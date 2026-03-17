<script lang="ts">
    import type { AnimeSummary } from "$lib/types/anime";
    import AnimeCard from "./AnimeCard.svelte";
    import { ArrowLeftIcon, ArrowRightIcon } from "phosphor-svelte";

    export let title: string;
    export let items: AnimeSummary[];

    let scrollContainer: HTMLDivElement;

    function scroll(direction: "left" | "right") {
        scrollContainer.scrollBy({
            left: direction === "right" ? 1000 : -1000,
            behavior: "smooth",
        });
    }
</script>

<section class="mb-8">
    <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold">{title}</h2>
        <div class="flex gap-1">
            <button
                on:click={() => scroll("left")}
                class="p-1 rounded hover:bg-white/10 transition"
            >
                <ArrowLeftIcon />
            </button>
            <button
                on:click={() => scroll("right")}
                class="p-1 rounded hover:bg-white/10 transition"
            >
                <ArrowRightIcon />
            </button>
        </div>
    </div>

    <div
        bind:this={scrollContainer}
        class="flex gap-3 overflow-x-auto pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden scroll-smooth snap-x snap-mandatory"
    >
        {#each items as anime (anime.id)}
            <div class="snap-start">
                <AnimeCard {anime} />
            </div>
        {/each}
    </div>
</section>
