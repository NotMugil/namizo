<script lang="ts">
    import type { AnimeSummary } from "$lib/types/anime";
    import { goto } from '$app/navigation'
    import { PlayIcon, PencilSimpleIcon, HeartIcon } from "phosphor-svelte";
    import TrailerSurface from "./shared/TrailerSurface.svelte";
    let favorited = false;
    export let anime: AnimeSummary;

    let hoverActive = false
    let hoverTimer: ReturnType<typeof setTimeout> | null = null

    function onHoverStart() {
        hoverTimer = setTimeout(() => { hoverActive = true }, 800)
    }

    function onHoverEnd() {
        if (hoverTimer) clearTimeout(hoverTimer)
        hoverActive = false
    }
</script>

<div
    class="group relative flex flex-col w-[200px] shrink-0 no-underline text-inherit rounded-xl"
    role="link"
    tabindex="0"
    onmouseenter={onHoverStart}
    onmouseleave={onHoverEnd}
    onclick={() => goto(`/anime/${anime.id}`)}
    onkeydown={(e) => e.key === 'Enter' && goto(`/anime/${anime.id}`)}
>
    <!-- Poster -->
    <div class="
        relative w-full aspect-[2/3] rounded-xl overflow-hidden
        border border-white/8
        bg-[#0d1420]
        transition-[box-shadow,border-color,filter] duration-150
        group-hover:shadow-[0_18px_32px_rgba(3,5,8,0.56)]
        group-hover:[filter:saturate(1.04)]
    ">
        <img
            src={anime.cover_image}
            alt={anime.title}
            class="w-full h-full object-cover"
            loading="lazy"
        />
        <!-- {#if anime.average_score}
            <span class="absolute bottom-1.5 left-1.5 bg-black/70 text-white text-[12px] px-1.5 py-[2px] rounded z-10">
                {anime.average_score / 10}
            </span>
        {/if} -->
    </div>

    <div class="pt-[6px] px-[2px]">
        <p class="text-[14px] m-0 line-clamp-2 leading-snug">
            {anime.title}
        </p>
        <p class="text-[12px] opacity-60 mt-[2px]">
            {anime.format ?? ""}
            {#if anime.episodes} · {anime.episodes} eps{/if}
        </p>
    </div>

    <div class="
        pointer-events-none
        absolute inset-0 rounded-xl overflow-hidden
        flex flex-col items-center justify-start gap-2 p-2.5
        bg-[linear-gradient(180deg,rgba(8,10,14,0.62),rgba(7,9,13,0.92))]
        backdrop-blur-[9px]
        border border-white/10
        shadow-[0_20px_38px_rgba(2,4,8,0.62)]
        opacity-0 translate-y-[7px]
        transition-[opacity,transform] duration-150
        group-hover:pointer-events-auto
        group-hover:opacity-100
        group-hover:translate-y-0
    ">
        <!-- 16:9 preview -->
        <div class="relative w-full aspect-video rounded-md overflow-hidden shrink-0 border border-white/8 bg-black/20">
            {#if anime.trailer_id && hoverActive}
                <TrailerSurface
                    image={ anime.banner_image ?? anime.cover_image ?? ""}
                    trailerId={anime.trailer_id}
                    />
            {:else}
                <img
                    src={anime.banner_image ?? anime.cover_image}
                    alt={anime.title}
                    class="w-full h-full object-cover"
                />
            {/if}
        </div>

        <!-- Title + meta -->
        <div class="flex flex-col items-center text-center gap-0.5">
            <p class="text-[14px] text-white  leading-snug line-clamp-2 m-0">
                {anime.title}
            </p>
            <p class="text-[11px] text-white/50 uppercase m-0">
                {anime.format ?? ""}
                {#if anime.episodes} · {anime.episodes} eps{/if}
            </p>
        </div>

        <a  href="/watch/{anime.id}?ep=1"
            class="inline-flex h-8 w-full items-center justify-center gap-1 rounded-md
            border border-white/20 bg-white/40 px-2.5 py-5 text-[0.81rem] font-nediun text-white
            transition-colors hover:bg-white/35"
            onclick={(e) => e.stopPropagation()}
        >
            <PlayIcon size={13} weight="fill" />
            <span >Watch</span>
        </a>

        <div class="flex items-center justify-center gap-2 mt-auto">
            <button
                class="inline-flex size-8 items-center justify-center rounded-lg
                border border-white/15 bg-white/10 text-white
                transition-colors hover:border-white/30"
                onclick={(e) => e.preventDefault()}
                aria-label="Edit planning state"
            >
                <PencilSimpleIcon size={13} weight="bold" />
            </button>
            <button
                class="inline-flex size-8 items-center justify-center rounded-lg
                border border-white/15 bg-white/10 text-white
                transition-colors hover:border-white/30"
                onclick={(e) => { e.preventDefault(); favorited = !favorited }}
                aria-label="Favorite"
            >
                <HeartIcon size={13} weight={favorited ? "fill" : "regular"} />
            </button>
        </div>
    </div>
</div>