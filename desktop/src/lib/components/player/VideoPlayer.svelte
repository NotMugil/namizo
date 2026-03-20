<script lang="ts">
    import { createEventDispatcher, onMount, onDestroy } from 'svelte'
    import Hls from 'hls.js'
    import {
        PlayIcon, PauseIcon,
        SpeakerHighIcon, SpeakerSlashIcon,
        CornersOutIcon, ArrowsOutIcon,
        SkipBackIcon, SkipForwardIcon,
        ClockClockwiseIcon, ClockCounterClockwiseIcon,
        MoonStarsIcon, PlayCircleIcon,
        DotsThreeVerticalIcon, SlidersHorizontalIcon
    } from 'phosphor-svelte'
    import * as Select from '$lib/components/ui/select'
    import type { StreamSource, StreamingEpisode } from '$lib/types/stream'

    const dispatch = createEventDispatcher()

    export let sources: StreamSource[] = []
    export let selectedSource: StreamSource | null = null
    export let playbackUrl: string | null = null
    export let sourceKind: string = 'hls'
    export let selectedEpisode: StreamingEpisode | null = null
    export let autoPlay: boolean
    export let autoNext: boolean
    export let focusMode: boolean
    export let animeTitle: string = ''
    export let provider: string = ''
    export let providerOptions: { label: string; value: string }[] = []
    export let loading: boolean = false
    export let statusMessage: string = ''
    export let mediaError: string = ''

    let videoEl: HTMLVideoElement | null = null
    let playerContainer: HTMLDivElement | null = null
    let playerSurfaceEl: HTMLDivElement | null = null
    let hlsInstance: Hls | null = null
    let settingsPanelEl: HTMLDivElement | null = null
    let settingsTriggerEl: HTMLButtonElement | null = null

    let playerState: 'idle' | 'loading' | 'playing' | 'paused' | 'buffering' | 'ended' | 'error' = 'idle'
    let muted = false
    let volumeLevel = 1
    let seekPercent = 0
    let currentTime = 0
    let duration = 0
    let fullscreen = false
    let fullscreenUiVisible = true
    let fullscreenTimer: ReturnType<typeof setTimeout> | null = null
    let settingsOpen = false
    let playbackRate = 1
    const HIDE_DELAY = 2600

    // ── Reactive: attach when playbackUrl changes ─────────────────────────────

    $: if (playbackUrl && videoEl) {
        attachPlayback(playbackUrl, sourceKind)
    }

    // ── HLS ───────────────────────────────────────────────────────────────────

    function cleanupHls() {
        hlsInstance?.destroy()
        hlsInstance = null
    }

    async function attachPlayback(url: string, kind: string) {
        if (!videoEl) return
        cleanupHls()
        videoEl.pause()
        videoEl.removeAttribute('src')
        playerState = 'loading'

        if (kind === 'hls' && Hls.isSupported()) {
            hlsInstance = new Hls({ lowLatencyMode: false })
            hlsInstance.on(Hls.Events.ERROR, (_, data) => {
                if (data.fatal) {
                    dispatch('hlsError', data)
                    playerState = 'error'
                }
            })
            hlsInstance.attachMedia(videoEl)
            hlsInstance.loadSource(url)
        } else if (videoEl.canPlayType('application/vnd.apple.mpegurl')) {
            videoEl.src = url
        } else {
            videoEl.src = url
        }

        videoEl.playbackRate = playbackRate
        if (autoPlay) {
            try { await videoEl.play() } catch {}
        }
    }

    // ── Controls ──────────────────────────────────────────────────────────────

    function togglePlayPause() {
        if (!videoEl) return
        videoEl.paused ? videoEl.play() : videoEl.pause()
    }

    function seekBy(secs: number) {
        if (!videoEl) return
        videoEl.currentTime = Math.max(0, Math.min(duration, videoEl.currentTime + secs))
    }

    function onSeekInput(e: Event) {
        if (!videoEl) return
        const val = Number((e.currentTarget as HTMLInputElement).value)
        seekPercent = val
        if (duration > 0) videoEl.currentTime = (val / 100) * duration
    }

    function onVolumeInput(e: Event) {
        if (!videoEl) return
        const val = Number((e.currentTarget as HTMLInputElement).value)
        volumeLevel = val
        videoEl.volume = val
        muted = val === 0
        videoEl.muted = muted
    }

    function toggleMute() {
        if (!videoEl) return
        videoEl.muted = !videoEl.muted
        muted = videoEl.muted
    }

    async function toggleFullscreen() {
        if (!playerSurfaceEl) return
        document.fullscreenElement
            ? await document.exitFullscreen()
            : await playerSurfaceEl.requestFullscreen()
    }

    function scheduleUiHide() {
        if (fullscreenTimer) clearTimeout(fullscreenTimer)
        if (!fullscreen) return
        fullscreenTimer = setTimeout(() => { fullscreenUiVisible = false }, HIDE_DELAY)
    }

    function onPlayerActivity() {
        if (!fullscreen) return
        fullscreenUiVisible = true
        scheduleUiHide()
    }

    function formatTime(secs: number): string {
        if (!Number.isFinite(secs)) return '00:00'
        const s = Math.max(0, Math.floor(secs))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = s % 60
        if (h > 0) return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:${String(sec).padStart(2,'0')}`
        return `${String(m).padStart(2,'0')}:${String(sec).padStart(2,'0')}`
    }

    function seekTrackStyle() {
        const p = Math.max(0, Math.min(100, seekPercent))
        return `--seek-fill:${p}%`
    }

    function volumeTrackStyle() {
        return `--seek-fill:${volumeLevel * 100}%`
    }

    function isPlaying() {
        if (!videoEl) return playerState === 'playing'
        return !videoEl.paused && !videoEl.ended && videoEl.readyState > 2
    }

    function onProviderChange(value: string) {
        dispatch('providerChange', value)
    }

    function onFullscreenChange() {
        fullscreen = Boolean(document.fullscreenElement)
        if (fullscreen) {
            fullscreenUiVisible = true
            scheduleUiHide()
        } else {
            fullscreenUiVisible = true
            if (fullscreenTimer) clearTimeout(fullscreenTimer)
        }
    }

    function onGlobalPointerDown(e: PointerEvent) {
        if (!settingsOpen) return
        const target = e.target as Node
        if (!settingsPanelEl?.contains(target) && !settingsTriggerEl?.contains(target)) {
            settingsOpen = false
        }
    }

    onMount(() => {
        document.addEventListener('fullscreenchange', onFullscreenChange)
        document.addEventListener('pointerdown', onGlobalPointerDown)
    })

    onDestroy(() => {
        cleanupHls()
        document.removeEventListener('fullscreenchange', onFullscreenChange)
        document.removeEventListener('pointerdown', onGlobalPointerDown)
        if (fullscreenTimer) clearTimeout(fullscreenTimer)
    })
</script>

<div
    class="relative flex flex-col gap-2 min-h-0"
    bind:this={playerContainer}
>
    <!-- Episode title bar -->
    {#if !fullscreen}
        <div class="flex items-start justify-between gap-3 px-0.5 py-1">
            <div class="min-w-0">
                <p class="text-[0.95rem] font-medium truncate">
                    {selectedEpisode ? `Episode ${selectedEpisode.number}` : 'Select Episode'}
                </p>
                <p class="text-[0.75rem] text-white/60 truncate">{animeTitle}</p>
            </div>

            {#if providerOptions.length}
                <Select.Root
                    type="single"
                    value={provider}
                    onValueChange={onProviderChange}
                >
                    <Select.Trigger
                        class="h-8 w-[160px] rounded-[10px] border border-white/12
                               bg-white/7 px-3 text-[0.78rem] text-white/85"
                    >
                        <div class="flex w-full items-center justify-between gap-1.5">
                            <span class="truncate">
                                {providerOptions.find((opt) => opt.value === provider)?.label ?? 'Provider'}
                            </span>
                            <SlidersHorizontalIcon size={13} weight="bold" />
                        </div>
                    </Select.Trigger>
                    <Select.Content>
                        {#each providerOptions as opt}
                            <Select.Item value={opt.value} label={opt.label} />
                        {/each}
                    </Select.Content>
                </Select.Root>
            {/if}
        </div>
    {/if}

    <!-- Player box -->
    <div
        bind:this={playerSurfaceEl}
        onmousemove={onPlayerActivity}
        role="presentation"
        class="group/player relative bg-black overflow-hidden
               shadow-[0_0_0_1px_rgba(255,255,255,0.08),0_0_28px_rgba(255,255,255,0.05)]
               {fullscreen
                   ? 'h-screen w-screen'
                   : 'aspect-video max-h-[calc(100vh-14rem)] xl:aspect-auto xl:h-[calc(100vh-11rem)]'}
               {fullscreen && !fullscreenUiVisible ? 'cursor-none' : ''}"
    >
        <video
            bind:this={videoEl}
            class="w-full h-full bg-black object-contain"
            playsinline
            onplay={() => { playerState = 'playing'; dispatch('play') }}
            onpause={() => { if (playerState !== 'ended') playerState = 'paused' }}
            onwaiting={() => playerState = 'buffering'}
            onended={() => {
                playerState = 'ended'
                dispatch('ended')
            }}
            ontimeupdate={() => {
                if (!videoEl) return
                currentTime = videoEl.currentTime
                duration = videoEl.duration || 0
                if (duration > 0) seekPercent = (currentTime / duration) * 100
            }}
            onerror={() => { playerState = 'error' }}
            onloadedmetadata={() => {
                if (videoEl) videoEl.playbackRate = playbackRate
            }}
        ></video>

        <!-- Fullscreen top gradient -->
        {#if fullscreen}
            <div class="pointer-events-none absolute inset-x-0 top-0 z-20 h-24
                        bg-gradient-to-b from-black/90 to-transparent
                        transition-opacity duration-200
                        {fullscreenUiVisible ? 'opacity-100' : 'opacity-0'}">
            </div>
        {/if}

        <!-- Fullscreen top bar -->
        {#if fullscreen}
            <div class="absolute inset-x-3 top-3 z-30 flex items-center justify-between
                        transition-opacity duration-200
                        {fullscreenUiVisible ? 'opacity-100' : 'pointer-events-none opacity-0'}">
                <div class="min-w-0">
                    <p class="text-[0.95rem] font-medium truncate text-white">
                        {selectedEpisode ? `Episode ${selectedEpisode.number}` : ''}
                    </p>
                    <p class="text-[0.75rem] text-white/60 truncate">{animeTitle}</p>
                </div>
            </div>
        {/if}

        <!-- Loading / idle overlay -->
        {#if loading || playerState === 'idle' || playerState === 'loading' || playerState === 'buffering'}
            <div class="absolute inset-0 grid place-items-center bg-black/50 z-10">
                {#if loading || playerState === 'loading' || playerState === 'buffering'}
                    <div class="grid place-items-center gap-2">
                        <div class="h-7 w-7 animate-spin rounded-full border-2 border-white/25 border-t-white"></div>
                        {#if statusMessage}
                            <p class="text-xs text-white/50 max-w-[240px] text-center">{statusMessage}</p>
                        {/if}
                    </div>
                {:else}
                    <p class="text-sm text-white/40">Select an episode to start playback.</p>
                {/if}
            </div>
        {/if}

        <!-- Error overlay -->
        {#if playerState === 'error' && mediaError}
            <div class="absolute inset-0 grid place-items-center bg-black/70 z-10">
                <p class="text-sm text-red-400 max-w-[280px] text-center">{mediaError}</p>
            </div>
        {/if}

        <!-- Bottom gradient -->
        <div class="pointer-events-none absolute inset-x-0 bottom-0 h-44
                    bg-gradient-to-t from-black/95 via-black/50 to-transparent
                    transition-opacity duration-200
                    {fullscreen
                        ? fullscreenUiVisible ? 'opacity-100' : 'opacity-0'
                        : 'opacity-0 group-hover/player:opacity-100'}">
        </div>

        <!-- Controls -->
        <div class="absolute inset-x-0 bottom-0 z-30 px-3 pb-2 pt-2
                    transition-opacity duration-200
                    {fullscreen
                        ? fullscreenUiVisible ? 'opacity-100' : 'pointer-events-none opacity-0'
                        : 'pointer-events-none opacity-0 group-hover/player:pointer-events-auto group-hover/player:opacity-100'}">

            <!-- Seek bar -->
            <input
                class="nm-slider w-full h-4 cursor-pointer appearance-none bg-transparent"
                style={seekTrackStyle()}
                type="range" min="0" max="100" step="0.1"
                bind:value={seekPercent}
                oninput={onSeekInput}
            />

            <!-- Time display -->
            <div class="flex justify-between text-[0.65rem] text-white/75 mt-0.5">
                <span>{formatTime(currentTime)}</span>
                <span>{formatTime(duration)}</span>
            </div>

            <!-- Button row -->
            <div class="flex items-center justify-between gap-2 mt-1.5">

                <!-- Left: volume -->
                <div class="flex items-center gap-1.5">
                    <button class="ctrl-btn" onclick={toggleMute} aria-label="Mute">
                        {#if muted}
                            <SpeakerSlashIcon size={16} weight="bold" />
                        {:else}
                            <SpeakerHighIcon size={16} weight="bold" />
                        {/if}
                    </button>
                    <input
                        class="nm-slider w-20 h-4 cursor-pointer appearance-none bg-transparent"
                        style={volumeTrackStyle()}
                        type="range" min="0" max="1" step="0.01"
                        bind:value={volumeLevel}
                        oninput={onVolumeInput}
                    />
                </div>

                <!-- Center: playback -->
                <div class="flex items-center gap-2">
                    <button class="ctrl-btn" onclick={() => seekBy(-10)} aria-label="Back 10s">
                        <ClockCounterClockwiseIcon size={17} weight="bold" />
                    </button>
                    <button
                        class="ctrl-btn !w-9 !h-9 !rounded-full"
                        onclick={togglePlayPause}
                        aria-label={isPlaying() ? 'Pause' : 'Play'}
                    >
                        {#if isPlaying()}
                            <PauseIcon size={17} weight="fill" />
                        {:else}
                            <PlayIcon size={17} weight="fill" />
                        {/if}
                    </button>
                    <button class="ctrl-btn" onclick={() => seekBy(10)} aria-label="Forward 10s">
                        <ClockClockwiseIcon size={17} weight="bold" />
                    </button>
                </div>

                <!-- Right: fullscreen + settings -->
                <div class="flex items-center gap-1.5 relative">
                    <button class="ctrl-btn" onclick={toggleFullscreen} aria-label="Fullscreen">
                        {#if fullscreen}
                            <ArrowsOutIcon size={15} weight="bold" />
                        {:else}
                            <CornersOutIcon size={15} weight="bold" />
                        {/if}
                    </button>

                    <button
                        bind:this={settingsTriggerEl}
                        class="ctrl-btn"
                        onclick={() => settingsOpen = !settingsOpen}
                        aria-label="Settings"
                    >
                        <DotsThreeVerticalIcon size={15} weight="bold" />
                    </button>

                    {#if settingsOpen}
                        <div
                            bind:this={settingsPanelEl}
                            class="absolute bottom-[calc(100%+0.5rem)] right-0 z-50
                                   w-[200px] grid gap-2 rounded-xl p-2.5
                                   border border-white/10 bg-black/90 backdrop-blur-xl
                                   shadow-[0_10px_28px_rgba(0,0,0,0.5)]"
                        >
                            <!-- Quality -->
                            {#if sources.length > 0}
                                <p class="settings-label">Quality</p>
                                <div class="grid grid-cols-2 gap-1">
                                    {#each sources as src}
                                        <button
                                            class="settings-option {selectedSource?.url === src.url ? 'settings-option-active' : ''}"
                                            onclick={() => {
                                                dispatch('sourceChange', src)
                                                settingsOpen = false
                                            }}
                                        >
                                            {src.quality}
                                        </button>
                                    {/each}
                                </div>
                            {/if}

                            <!-- Speed -->
                            <p class="settings-label">Speed</p>
                            <div class="grid grid-cols-3 gap-1">
                                {#each [0.5, 0.75, 1, 1.25, 1.5, 2] as speed}
                                    <button
                                        class="settings-option {playbackRate === speed ? 'settings-option-active' : ''}"
                                        onclick={() => {
                                            playbackRate = speed
                                            if (videoEl) videoEl.playbackRate = speed
                                            settingsOpen = false
                                        }}
                                    >
                                        {speed}x
                                    </button>
                                {/each}
                            </div>
                        </div>
                    {/if}
                </div>
            </div>
        </div>
    </div>

    <!-- Control strip -->
    {#if !fullscreen}
        <div class="flex overflow-hidden rounded-lg border border-white/8">
            <button
                class="strip-btn {autoPlay ? 'strip-btn-active' : ''}"
                onclick={() => dispatch('toggleAutoPlay')}
            >
                <PlayIcon size={12} weight="fill" /> Auto Play
            </button>
            <span class="strip-divider"></span>
            <button
                class="strip-btn {autoNext ? 'strip-btn-active' : ''}"
                onclick={() => dispatch('toggleAutoNext')}
            >
                <PlayCircleIcon size={13} weight="fill" /> Auto Next
            </button>
            <span class="strip-divider"></span>
            <button
                class="strip-btn {focusMode ? 'strip-btn-active' : ''}"
                onclick={() => dispatch('toggleFocus')}
            >
                <MoonStarsIcon size={13} weight="bold" /> Focus
            </button>
            <span class="strip-divider"></span>
            <button
                class="strip-btn disabled:opacity-30"
                disabled={!selectedEpisode}
                onclick={() => dispatch('playPrev')}
            >
                <SkipBackIcon size={12} weight="bold" /> Prev
            </button>
            <span class="strip-divider"></span>
            <button
                class="strip-btn disabled:opacity-30"
                disabled={!selectedEpisode}
                onclick={() => dispatch('playNext')}
            >
                <SkipForwardIcon size={12} weight="bold" /> Next
            </button>
        </div>

        <!-- Error / status message -->
        {#if mediaError}
            <p class="text-xs text-red-400 truncate px-0.5">{mediaError}</p>
        {:else if statusMessage}
            <p class="text-xs text-white/40 truncate px-0.5">{statusMessage}</p>
        {/if}
    {/if}
</div>

<style>
    .ctrl-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 2rem;
        height: 2rem;
        border-radius: 8px;
        border: 0;
        background: transparent;
        color: rgba(255,255,255,0.88);
        cursor: pointer;
        transition: color 150ms;
    }
    .ctrl-btn:hover { color: #fff; }

    .strip-btn {
        display: inline-flex;
        flex: 1;
        height: 2.2rem;
        align-items: center;
        justify-content: center;
        gap: 0.35rem;
        font-size: 0.74rem;
        background: transparent;
        color: rgba(255,255,255,0.55);
        border: 0;
        cursor: pointer;
        transition: background-color 150ms, color 150ms;
    }
    .strip-btn:hover { background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.8); }
    .strip-btn-active { background: rgba(255,255,255,0.1); color: #fff; }
    .strip-divider { width: 1px; align-self: stretch; background: rgba(255,255,255,0.08); }

    .settings-label {
        margin: 0;
        font-size: 0.65rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: rgba(255,255,255,0.4);
        padding: 0 0.25rem;
    }
    .settings-option {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        height: 1.9rem;
        border-radius: 8px;
        font-size: 0.74rem;
        background: rgba(255,255,255,0.07);
        color: rgba(255,255,255,0.7);
        border: 0;
        cursor: pointer;
        transition: background-color 150ms;
    }
    .settings-option:hover { background: rgba(255,255,255,0.12); }
    .settings-option-active { background: rgba(255,255,255,0.18); color: #fff; }

    .nm-slider { --seek-fill: 0%; }
    .nm-slider::-webkit-slider-runnable-track {
        height: 3px;
        border-radius: 999px;
        background: linear-gradient(
            to right,
            rgba(255,255,255,0.95) 0 var(--seek-fill),
            rgba(255,255,255,0.22) var(--seek-fill) 100%
        );
    }
    .nm-slider::-webkit-slider-thumb {
        -webkit-appearance: none;
        appearance: none;
        margin-top: -4.5px;
        width: 12px;
        height: 12px;
        border-radius: 999px;
        background: #fff;
        border: 0;
    }
    .nm-slider::-moz-range-track {
        height: 3px;
        border-radius: 999px;
        background: rgba(255,255,255,0.22);
    }
    .nm-slider::-moz-range-progress {
        height: 3px;
        border-radius: 999px;
        background: rgba(255,255,255,0.95);
    }
    .nm-slider::-moz-range-thumb {
        width: 12px;
        height: 12px;
        border-radius: 999px;
        background: #fff;
        border: 0;
    }
</style>
