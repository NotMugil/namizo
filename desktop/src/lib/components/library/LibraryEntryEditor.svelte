<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import { onDestroy } from "svelte";
    import { librarySave } from "$lib/api/library";
    import type { LibraryEntry, LibraryState } from "$lib/types/library";
    import SelectPicker from "$lib/components/ui/select/SelectPicker.svelte";
    import DatePicker from "$lib/components/ui/date/DatePicker.svelte";
    import Textarea from "$lib/components/ui/textarea/Textarea.svelte";
    import { toast } from "svelte-sonner";

    export let open = false;
    export let entry: LibraryEntry | null = null;

    const dispatch = createEventDispatcher<{ saved: LibraryEntry }>();

    const statusOptions: Array<{ value: LibraryState; label: string }> = [
        { value: "PLANNING", label: "Planning" },
        { value: "WATCHING", label: "Watching" },
        { value: "REWATCHING", label: "Rewatching" },
        { value: "PAUSED", label: "Paused" },
        { value: "DROPPED", label: "Dropped" },
        { value: "COMPLETED", label: "Completed" },
    ];

    let status = "PLANNING";
    let progress: string | number = "0";
    let score: string | number = "";
    let startDate = "";
    let endDate = "";
    let rewatches: string | number = "0";
    let notes = "";

    let saving = false;
    let notice = "";
    let primeKey = "";
    let scrollLocked = false;
    let previousBodyOverflow = "";
    let previousHtmlOverflow = "";

    function posterUrl(): string {
        return entry?.cover_image || "/favicon.png";
    }

    function close() {
        if (saving) return;
        open = false;
    }

    function normalizeInt(value: string | number | null | undefined, fallback: number): number {
        if (value === null || value === undefined) return fallback;
        if (typeof value === "string" && value.trim().length === 0) return fallback;
        const parsed = Number(value);
        if (!Number.isFinite(parsed)) return fallback;
        return Math.max(0, Math.trunc(parsed));
    }

    function clampScore(value: string | number | null | undefined): number | null {
        if (value === null || value === undefined) return null;
        if (typeof value === "string" && value.trim().length === 0) return null;
        const parsed = Number(value);
        if (!Number.isFinite(parsed)) return null;
        if (parsed <= 0) return null; // treat 0 as "not scored"
        return Math.min(10, Math.trunc(parsed));
    }

    async function save(event: SubmitEvent) {
        event.preventDefault();
        if (!entry || saving) return;

        const rawProgress = normalizeInt(progress, entry.progress);
        const boundedProgress = entry.episode_total != null
            ? Math.min(rawProgress, entry.episode_total)
            : rawProgress;
        const nextScore = clampScore(score);
        const nextRewatches = normalizeInt(rewatches, entry.rewatches ?? 0);

        if (entry.episode_total != null && rawProgress !== boundedProgress) {
            notice = `Progress capped at ${entry.episode_total} episodes.`;
        } else {
            notice = "";
        }

        if (startDate && endDate && startDate > endDate) {
            notice = "Start date cannot be after end date.";
            return;
        }

        const nextProgressPercent = entry.episode_total && entry.episode_total > 0
            ? Math.round((boundedProgress / entry.episode_total) * 100)
            : entry.progress_percent;

        saving = true;
        try {
            const saved = await librarySave({
                ...entry,
                status: status as LibraryState,
                progress: boundedProgress,
                progress_percent: Math.max(0, Math.min(100, nextProgressPercent)),
                score: nextScore,
                start_date: startDate || null,
                end_date: endDate || null,
                rewatches: nextRewatches,
                notes: notes.trim() || null,
            });

            toast.success("Saved changes to your collection.");
            dispatch("saved", saved);
            open = false;
        } catch (error) {
            const message = `Failed to save changes: ${String(error)}`;
            notice = message;
            toast.error(message);
        } finally {
            saving = false;
        }
    }

    function onWindowKeydown(event: KeyboardEvent) {
        if (!open || saving) return;
        if (event.key === "Escape") {
            event.preventDefault();
            close();
        }
    }

    function setScrollLock(locked: boolean) {
        if (typeof document === "undefined") return;

        if (locked && !scrollLocked) {
            previousBodyOverflow = document.body.style.overflow;
            previousHtmlOverflow = document.documentElement.style.overflow;
            document.body.style.overflow = "hidden";
            document.documentElement.style.overflow = "hidden";
            scrollLocked = true;
            return;
        }

        if (!locked && scrollLocked) {
            document.body.style.overflow = previousBodyOverflow;
            document.documentElement.style.overflow = previousHtmlOverflow;
            scrollLocked = false;
        }
    }

    onDestroy(() => {
        setScrollLock(false);
    });

    $: {
        const key = open && entry ? `${entry.anilist_id}:${entry.updated_at}` : "";
        if (key && key !== primeKey) {
            status = entry?.status ?? "PLANNING";
            progress = String(entry?.progress ?? 0);
            score = entry?.score != null && entry.score > 0 ? String(entry.score) : "";
            startDate = entry?.start_date ?? "";
            endDate = entry?.end_date ?? "";
            rewatches = String(entry?.rewatches ?? 0);
            notes = entry?.notes ?? "";

            notice = "";
            primeKey = key;
        }
        if (!open) {
            primeKey = "";
            notice = "";
        }
    }

    $: setScrollLock(open);
</script>

<svelte:window on:keydown={onWindowKeydown} />

{#if open && entry}
    <button
        type="button"
        aria-label="Close editor"
        class="fixed inset-0 z-[95] bg-black/72 backdrop-blur-[4px]"
        onclick={close}
    ></button>

    <div class="fixed left-1/2 top-1/2 z-[100] w-[min(920px,calc(100vw-1.5rem))] -translate-x-1/2 -translate-y-1/2 rounded-xl border border-white/15 bg-black/68 p-0 text-white shadow-[0_35px_90px_rgba(0,0,0,0.55)] backdrop-blur-[26px]">

        <div class="grid gap-4 md:grid-cols-[minmax(200px,240px)_minmax(0,1fr)]">
            <div class="overflow-hidden rounded-tl-lg rounded-bl-lg border border-white/15 bg-black/30">
                <img src={posterUrl()} alt={entry.title} class="block h-full w-full object-cover" loading="lazy" />
            </div>

            <form class="grid gap-3 p-5 rounded-lg" onsubmit={save}>
                <h2 class="text-lg font-semibold">{entry.title}</h2>
                <div class="grid gap-3 lg:grid-cols-3">
                    <label class="grid gap-1 text-sm">
                        <span class="text-white/80">Watch status</span>
                        <SelectPicker
                            items={statusOptions}
                            bind:value={status}
                            onChange={(value) => (status = value)}
                            triggerClass="h-9 w-full rounded-[10px] border border-white/15 bg-white/10"
                            contentClass="z-[140]"
                        />
                    </label>
                    <label class="grid gap-1 text-sm">
                        <span class="text-white/80">Start date</span>
                        <DatePicker bind:value={startDate} max={endDate || undefined} placeholder="Pick start date" />
                    </label>
                    <label class="grid gap-1 text-sm">
                        <span class="text-white/80">End date</span>
                        <DatePicker bind:value={endDate} min={startDate || undefined} placeholder="Pick end date" />
                    </label>
                </div>

                <div class="grid gap-3 sm:grid-cols-3">
                    <label class="grid gap-1 text-sm">
                        <span class="text-white/80">Your score (0-10)</span>
                        <input
                            type="number"
                            min="0"
                            max="10"
                            step="1"
                            bind:value={score}
                            class="h-9 w-full rounded-[10px] border border-white/15 bg-white/10 px-3 text-sm text-white outline-none focus:border-white/35"
                            placeholder="Not scored"
                        />
                    </label>
                    <label class="grid gap-1 text-sm">
                        <span class="text-white/80">Episodes watched</span>
                        <input
                            type="number"
                            min="0"
                            max={entry.episode_total ?? undefined}
                            step="1"
                            bind:value={progress}
                            class="h-9 w-full rounded-[10px] border border-white/15 bg-white/10 px-3 text-sm text-white outline-none focus:border-white/35"
                        />
                    </label>
                    <label class="grid gap-1 text-sm">
                        <span class="text-white/80">Total rewatches</span>
                        <input
                            type="number"
                            min="0"
                            step="1"
                            bind:value={rewatches}
                            class="h-9 w-full rounded-[10px] border border-white/15 bg-white/10 px-3 text-sm text-white outline-none focus:border-white/35"
                        />
                    </label>
                </div>

                <label class="grid gap-1 text-sm">
                    <span class="text-white/80">Notes</span>
                    <Textarea bind:value={notes} rows={4} placeholder="Add personal notes..." />
                </label>

                {#if notice}
                    <p class="text-xs text-amber-300">{notice}</p>
                {/if}

                <div class="mt-2 flex justify-end gap-2">
                    <button
                        type="button"
                        class="rounded-md border border-white/20 bg-transparent px-4 py-2 text-sm text-white transition-colors hover:bg-white/10"
                        onclick={close}
                    >
                        Cancel
                    </button>
                    <button
                        type="submit"
                        class="rounded-md border border-white/20 bg-white/90 px-4 py-2 text-sm font-medium text-black transition-colors hover:bg-white"
                        disabled={saving}
                    >
                        {saving ? "Saving..." : "Save changes"}
                    </button>
                </div>
            </form>
        </div>
    </div>
{/if}