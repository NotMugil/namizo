<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import { MagnifyingGlassIcon, FunnelSimpleIcon } from "phosphor-svelte";
    import * as Select from "$lib/components/ui/select";

    const dispatch = createEventDispatcher();

    export let episodeNumbers: number[] = [];
    export let fillerNumbers: Set<number> = new Set();
    export let recapNumbers: Set<number> = new Set();
    export let selectedNumber: number = 1;
    export let loading: boolean = false;

    let search = "";
    let range = "0-100";

    $: normalized = [...episodeNumbers].sort((a, b) => a - b);
    $: maxEpisode = normalized.length ? normalized[normalized.length - 1] : 0;

    $: rangeOptions = (() => {
        if (maxEpisode <= 0) {
            return [{ value: "0-100", label: "0-100" }];
        }

        const options: Array<{ value: string; label: string }> = [];
        for (let start = 0; start < maxEpisode; start += 100) {
            const end = start + 100;
            options.push({
                value: `${start}-${end}`,
                label: `${start}-${end}`,
            });
        }
        return options;
    })();

    $: if (!rangeOptions.some((option) => option.value === range)) {
        range = rangeOptions[0]?.value ?? "0-100";
    }

    function parseRange(value: string): { start: number; end: number } {
        const [rawStart, rawEnd] = value.split("-");
        const start = Number(rawStart);
        const end = Number(rawEnd);
        if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
            return { start: 0, end: 100 };
        }
        return { start, end };
    }

    $: bounds = parseRange(range);
    $: inRange = normalized.filter(
        (number) => number > bounds.start && number <= bounds.end,
    );
    $: filtered = search.trim()
        ? inRange.filter((number) => String(number).includes(search.trim()))
        : inRange;

    $: skeletonCount = Math.min(100, Math.max(24, inRange.length || 24));
</script>

<div class="flex h-full min-h-0 flex-col gap-2">
    <div class="flex flex-wrap items-center gap-1.5">
        <div class="relative min-w-[170px] flex-1">
            <MagnifyingGlassIcon
                size={12}
                weight="bold"
                class="absolute left-2 top-1/2 -translate-y-1/2 text-white/35"
            />
            <input
                class="h-8 w-full rounded-[8px] border border-white/12 bg-white/6 pl-7 pr-2
                       text-[0.74rem] text-white outline-none placeholder:text-white/35
                       focus:border-white/25"
                placeholder="Search episodes..."
                bind:value={search}
            />
        </div>

        <Select.Root
            type="single"
            value={range}
            onValueChange={(value) => {
                range = value;
            }}
        >
            <Select.Trigger
                class="h-8 min-w-[96px] rounded-[8px] border border-white/12 bg-white/6 px-2
                       text-[0.72rem] text-white/80"
            >
                <div class="flex items-center gap-1.5">
                    <FunnelSimpleIcon size={12} weight="bold" />
                    <span>{range}</span>
                </div>
            </Select.Trigger>
            <Select.Content>
                {#each rangeOptions as option}
                    <Select.Item value={option.value} label={option.label} />
                {/each}
            </Select.Content>
        </Select.Root>
    </div>

    <div class="flex-1 min-h-0">
        {#if loading}
            <div
                class="grid h-full min-h-0 content-start gap-1 overflow-y-auto pr-0.5
                        grid-cols-5 sm:grid-cols-6 md:grid-cols-8"
            >
                {#each Array.from({ length: skeletonCount }) as _, index}
                    <div
                        class="h-7 animate-pulse rounded-[7px] bg-white/7"
                        data-skeleton={index}
                    ></div>
                {/each}
            </div>
        {:else if filtered.length === 0}
            <div class="flex h-full items-start">
                <p
                    class="rounded-[10px] bg-white/6 px-3 py-2 text-[0.78rem] text-white/55"
                >
                    No episodes in this range.
                </p>
            </div>
        {:else}
            <div
                class="grid h-full min-h-0 content-start gap-1 overflow-y-auto pr-0.5
                        grid-cols-5 sm:grid-cols-6 md:grid-cols-8"
            >
                {#each filtered as number}
                    {@const isActive = number === selectedNumber}
                    {@const isFiller = fillerNumbers.has(number)}
                    {@const isRecap = recapNumbers.has(number)}

                    <button
                        class="inline-flex h-7 w-full items-center justify-center rounded-[7px] text-[0.74rem] font-semibold transition-colors
                        {isActive
                            ? 'bg-[color-mix(in_srgb,rgba(255,255,255,0.35)_45%,rgba(255,255,255,0.05))] text-white'
                            : isFiller
                              ? 'bg-orange-500/12 text-orange-300/80 hover:bg-orange-500/20'
                              : isRecap
                                ? 'bg-blue-500/12 text-blue-300/80 hover:bg-blue-500/20'
                                : 'bg-white/6 text-white/70 hover:bg-white/12'}"
                        onclick={() => dispatch("select", number)}
                    >
                        {number}
                    </button>
                {/each}
            </div>
        {/if}
    </div>

    <div
        class="mt-auto flex items-center justify-end gap-2 text-[0.65rem] text-white/35"
    >
        <div class="flex items-center gap-2">
            <span class="flex items-center gap-1">
                <span class="h-2 w-2 rounded-sm bg-orange-500/30"></span>
                Filler
            </span>
            <span class="flex items-center gap-1">
                <span class="h-2 w-2 rounded-sm bg-blue-500/30"></span>
                Recap
            </span>
        </div>
    </div>
</div>