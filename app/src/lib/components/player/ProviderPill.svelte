<script lang="ts">
    export let options: { label: string; value: string }[] = [];
    export let value: string = '';
    export let onChange: ((v: string) => void) | undefined = undefined;

    let open = false;

    $: selected = options.find(o => o.value === value) ?? options[0];

    function pick(v: string) {
        open = false;
        if (v !== value) onChange?.(v);
    }

    function onKeyDown(e: KeyboardEvent) {
        if (e.key === 'Escape') open = false;
    }
</script>

<svelte:window on:keydown={onKeyDown} />

<div class="relative">
    <!-- Trigger — matches the Share button pill style -->
    <button
        type="button"
        class="flex items-center gap-1.5 h-8 px-3.5 rounded-full border text-[12px] font-medium
               bg-white/5 border-white/10 text-white/55 hover:bg-white/10 hover:border-white/20 hover:text-white/80
               transition-all duration-150"
        onclick={() => (open = !open)}
        aria-haspopup="listbox"
        aria-expanded={open}
    >
        <!-- Server icon -->
        <svg width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/>
            <line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/>
        </svg>
        {selected?.label ?? '—'}
        <svg width="11" height="11" fill="none" stroke="currentColor" stroke-width="2.2" viewBox="0 0 24 24"
            class="text-white/40 transition-transform duration-150 {open ? 'rotate-180' : ''}">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
        </svg>
    </button>

    {#if open}
        <!-- Backdrop -->
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div class="fixed inset-0 z-40" onclick={() => (open = false)}></div>

        <!-- Dropdown (opens upward so it stays above EpisodeInfo) -->
        <div
            class="absolute bottom-full left-0 mb-2 z-50 w-52
                   rounded-2xl border border-white/10 bg-[rgba(16,18,24,0.92)] backdrop-blur-xl
                   shadow-[0_20px_44px_rgba(0,0,0,0.65)] overflow-hidden"
            role="listbox"
            aria-label="Streaming source"
        >
            <div class="p-2 space-y-0.5">
                {#each options as opt (opt.value)}
                    {@const isActive = opt.value === value}
                    <button
                        type="button"
                        class="w-full text-left flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-100
                               {isActive
                                 ? 'bg-white/12 border border-white/14'
                                 : 'hover:bg-white/6 border border-transparent hover:border-white/8'}"
                        onclick={() => pick(opt.value)}
                        role="option"
                        aria-selected={isActive}
                    >
                        <!-- Radio dot -->
                        <div class="flex-shrink-0 w-4 h-4 rounded-full border-2 flex items-center justify-center transition-colors
                                    {isActive ? 'border-white bg-white' : 'border-white/30'}">
                            {#if isActive}
                                <div class="w-1.5 h-1.5 rounded-full bg-black"></div>
                            {/if}
                        </div>
                        <span class="text-[13px] font-medium {isActive ? 'text-white' : 'text-white/65'}">{opt.label}</span>
                        {#if isActive}
                            <svg width="10" height="10" fill="white" viewBox="0 0 20 20" class="ml-auto opacity-60">
                                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                            </svg>
                        {/if}
                    </button>
                {/each}
            </div>
            <div class="border-t border-white/8 px-4 py-2 flex items-center gap-1.5">
                <svg width="11" height="11" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" class="text-white/25 shrink-0">
                    <circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/>
                </svg>
                <p class="text-[10px] text-white/25">Switching source reloads the episode</p>
            </div>
        </div>
    {/if}
</div>
