<script lang="ts">
    import { onDestroy, onMount } from "svelte";
    import Hls from "hls.js";
    import {
        ArrowsOutIcon,
        CircleHalfIcon,
        ClockClockwiseIcon,
        ClockCounterClockwiseIcon,
        CornersOutIcon,
        DotsThreeVerticalIcon,
        PauseIcon,
        PlayIcon,
        PlayCircleIcon,
        RectangleIcon,
        SkipBackIcon,
        SkipForwardIcon,
        SpeakerHighIcon,
        SpeakerSlashIcon,
    } from "phosphor-svelte";
    import type { StreamSource, StreamingEpisode } from "$lib/types/stream";
    import { findAdjacentEpisode } from "$lib/utils/watch/episodes";
    import SelectPicker from "$lib/components/ui/select/SelectPicker.svelte";
    import {
        FRAG_PARSING_RECOVER_THRESHOLD,
        FRAG_PARSING_WINDOW_MS,
        FULLSCREEN_UI_HIDE_DELAY_MS,
        HLS_MAX_RECOVERY_ATTEMPTS,
        HLS_PLAYER_CONFIG,
        HLS_RECOVERY_COOLDOWN_MS,
        HLS_RECOVERY_WINDOW_MS,
    } from "$lib/constants/player";
    import {
        describeVideoErrorCode,
        firstSupportedHlsLevel,
        formatPlaybackTime,
        normalizeAudioCodec,
        pathIsHls,
    } from "$lib/utils/player";

    type PlayerEventDetail = {
        type?: string;
        message?: string;
        detail?: unknown;
    };

    export let sources: StreamSource[] = [];
    export let selectedSource: StreamSource | null = null;
    export let playbackUrl: string | null = null;
    export let sourceKind: string = "hls";
    export let selectedEpisode: StreamingEpisode | null = null;
    export let episodeNumbers: number[] = [];
    export let selectedNumber: number = 0;
    export let episodeTitle: string = "";
    export let autoPlay: boolean;
    export let autoNext: boolean;
    export let focusMode: boolean;
    export let theatreMode: boolean;
    export let animeTitle: string = "";
    export let provider: string = "";
    export let providerOptions: { label: string; value: string }[] = [];
    export let loading: boolean = false;
    export let statusMessage: string = "";
    export let mediaError: string = "";
    export let onSourceChange: ((source: StreamSource) => void) | undefined =
        undefined;
    export let onProviderChange: ((provider: string) => void) | undefined =
        undefined;
    export let onToggleAutoPlay: (() => void) | undefined = undefined;
    export let onToggleAutoNext: (() => void) | undefined = undefined;
    export let onToggleFocus: (() => void) | undefined = undefined;
    export let onToggleTheatre: (() => void) | undefined = undefined;
    export let onEpisodeSelect: ((episodeNumber: number) => void) | undefined =
        undefined;
    export let onPlay: (() => void) | undefined = undefined;
    export let onReady: (() => void) | undefined = undefined;
    export let onEnded: (() => void) | undefined = undefined;
    export let onStartupError:
        | ((event: PlayerEventDetail) => void)
        | undefined = undefined;
    export let onFatalHls: ((event: PlayerEventDetail) => void) | undefined =
        undefined;
    export let onMediaError:
        | ((event: PlayerEventDetail) => void)
        | undefined = undefined;
    export let onHlsInfo: ((event: PlayerEventDetail) => void) | undefined =
        undefined;

    function dispatch(name: "sourceChange", detail: StreamSource): void;
    function dispatch(name: "providerChange", detail: string): void;
    function dispatch(
        name: "episodeSelect",
        detail: number | null | undefined,
    ): void;
    function dispatch(
        name: "startup_error" | "fatal_hls" | "media_error" | "hls_info",
        detail: PlayerEventDetail,
    ): void;
    function dispatch(
        name:
            | "play"
            | "ready"
            | "ended"
            | "toggleAutoPlay"
            | "toggleAutoNext"
            | "toggleFocus"
            | "toggleTheatre",
    ): void;
    function dispatch(name: string, detail?: unknown) {
        switch (name) {
            case "sourceChange":
                onSourceChange?.(detail as StreamSource);
                return;
            case "providerChange":
                onProviderChange?.(detail as string);
                return;
            case "episodeSelect":
                if (typeof detail === "number" && Number.isFinite(detail)) {
                    onEpisodeSelect?.(detail);
                }
                return;
            case "startup_error":
                onStartupError?.(detail as PlayerEventDetail);
                return;
            case "fatal_hls":
                onFatalHls?.(detail as PlayerEventDetail);
                return;
            case "media_error":
                onMediaError?.(detail as PlayerEventDetail);
                return;
            case "hls_info":
                onHlsInfo?.(detail as PlayerEventDetail);
                return;
            case "play":
                onPlay?.();
                return;
            case "ready":
                onReady?.();
                return;
            case "ended":
                onEnded?.();
                return;
            case "toggleAutoPlay":
                onToggleAutoPlay?.();
                return;
            case "toggleAutoNext":
                onToggleAutoNext?.();
                return;
            case "toggleFocus":
                onToggleFocus?.();
                return;
            case "toggleTheatre":
                onToggleTheatre?.();
                return;
            default:
                return;
        }
    }

    let videoEl: HTMLVideoElement | null = null;
    let playerShellEl: HTMLDivElement | null = null;
    let hlsInstance: Hls | null = null;
    let attachNonce = 0;
    let startupTimer: ReturnType<typeof setTimeout> | null = null;
    let attachedPlaybackKey: string | null = null;
    let settingsOpen = false;
    let settingsPanelEl: HTMLDivElement | null = null;
    let settingsButtonEl: HTMLButtonElement | null = null;
    let isFullscreen = false;
    let fullscreenUiVisible = true;
    let fullscreenUiTimer: ReturnType<typeof setTimeout> | null = null;
    let bufferingRecoveryTimer: ReturnType<typeof setTimeout> | null = null;
    let lastHlsRecoveryAt = 0;
    let hlsRecoveryAttempts = 0;
    let hlsRecoveryWindowStart = 0;
    let fragParsingErrorCount = 0;
    let fragParsingWindowStart = 0;
    let playbackRate = 1;
    let fitMode: "contain" | "cover" = "cover";
    let currentTimeSec = 0;
    let durationSec = 0;
    let bufferedPercent = 0;
    let seekPercent = 0;
    let volumeLevel = 1;
    let muted = false;
    let playerState: "idle" | "playing" | "paused" | "buffering" | "error" =
        "idle";
    let showPauseIcon = false;
    const playbackRates = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];

    $: showPauseIcon = playerState === "playing" || playerState === "buffering";
    $: prevEpisodeNumber = findAdjacentEpisode(
        episodeNumbers,
        selectedNumber,
        "prev",
    );
    $: nextEpisodeNumber = findAdjacentEpisode(
        episodeNumbers,
        selectedNumber,
        "next",
    );

    $: if (playbackUrl && videoEl) {
        const key = `${playbackUrl}::${sourceKind}`;
        if (attachedPlaybackKey !== key) {
            attachedPlaybackKey = key;
            void attachPlayback(playbackUrl, sourceKind);
        }
    }

    $: if (!playbackUrl) {
        attachedPlaybackKey = null;
        teardownPlayback(true);
        resetHlsRecoveryState();
        playerState = "idle";
        currentTimeSec = 0;
        durationSec = 0;
        bufferedPercent = 0;
        seekPercent = 0;
    }

    function clearStartupTimer() {
        if (!startupTimer) return;
        clearTimeout(startupTimer);
        startupTimer = null;
    }

    function destroyHls() {
        hlsInstance?.destroy();
        hlsInstance = null;
    }

    function teardownPlayback(resetVideo: boolean) {
        clearStartupTimer();
        clearBufferingRecoveryTimer();
        destroyHls();

        if (resetVideo && videoEl) {
            videoEl.pause();
            videoEl.removeAttribute("src");
            videoEl.load();
        }
    }

    function canPlayNativeHls(): boolean {
        if (!videoEl) return false;
        const support = videoEl.canPlayType("application/vnd.apple.mpegurl");
        return support === "probably" || support === "maybe";
    }

    async function safeAutoplay(nonce: number, attachPath: string) {
        if (!videoEl || !autoPlay || nonce !== attachNonce) return;

        try {
            await videoEl.play();
            clearStartupTimer();
        } catch (error) {
            const message =
                error instanceof Error ? error.message : String(error);
            if (message.toLowerCase().includes("notallowed")) return;
            if (
                message.toLowerCase().includes("interrupted by a call to pause")
            )
                return;
            if (
                message
                    .toLowerCase()
                    .includes("interrupted by a new load request")
            )
                return;
            clearStartupTimer();
            dispatch("startup_error", {
                type: "startup_error",
                message: `[${attachPath}] ${message}`,
                detail: error,
            });
        }
    }

    async function attachPlayback(url: string, kind: string) {
        if (!videoEl) return;

        teardownPlayback(true);
        resetHlsRecoveryState();
        playerState = "buffering";
        currentTimeSec = 0;
        durationSec = 0;
        seekPercent = 0;
        const nonce = ++attachNonce;
        const useHls = pathIsHls(url, kind);
        const nativeHlsSupported = useHls && canPlayNativeHls();
        const hlsJsSupported = useHls && Hls.isSupported();
        const useHlsJs = useHls && hlsJsSupported;
        const attachPath = useHlsJs ? "hls.js" : "native-src";
        let attemptedNativeCodecFallback = false;

        console.info(
            `[player] attach path=${attachPath} kind=${kind} url=${url} native_hls=${nativeHlsSupported} hlsjs_supported=${hlsJsSupported}`,
        );
        dispatch("hls_info", {
            type: "hls_info",
            message: `[player] attach path=${attachPath} native_hls=${String(nativeHlsSupported)} hlsjs_supported=${String(hlsJsSupported)}`,
        });

        if (autoPlay) {
            startupTimer = setTimeout(() => {
                if (nonce !== attachNonce) return;
                dispatch("startup_error", {
                    type: "startup_error",
                    message: `[${attachPath}] playback startup timed out`,
                });
            }, 12_000);
        }

        videoEl.playbackRate = playbackRate;

        if (useHlsJs) {
            hlsInstance = new Hls(HLS_PLAYER_CONFIG);
            hlsInstance.on(Hls.Events.ERROR, (_, data) => {
                if (nonce !== attachNonce) return;
                if (!data.fatal) {
                    const detail = (data.details ?? "").toLowerCase();
                    dispatch("hls_info", {
                        type: "hls_info",
                        message: `[hls.js] nonfatal type=${data.type ?? "unknown"} details=${data.details ?? "unknown"}`,
                    });

                    if (detail.includes("bufferseekoverhole")) {
                        alignPlaybackToBufferedRange();
                        playerState = "buffering";
                        scheduleBufferingRecovery("buffer_seek_over_hole");
                        void tryRecoverHlsPlayback("buffer_seek_over_hole");
                        return;
                    }

                    if (detail.includes("fragparsingerror")) {
                        const burstCount = noteFragParsingError();
                        const shouldRecoverMedia =
                            burstCount >= FRAG_PARSING_RECOVER_THRESHOLD;
                        playerState = "buffering";
                        alignPlaybackToBufferedRange();
                        scheduleBufferingRecovery(
                            `frag_parsing_error:${burstCount}`,
                        );
                        void tryRecoverHlsPlayback(
                            `frag_parsing_error:${burstCount}`,
                            {
                                recoverMediaError: shouldRecoverMedia,
                            },
                        );
                        return;
                    }

                    const shouldRecover =
                        detail.includes("bufferstalled") ||
                        detail.includes("fragload") ||
                        detail.includes("levelload") ||
                        detail.includes("internalexception") ||
                        detail.includes("timeout");
                    if (shouldRecover) {
                        playerState = "buffering";
                        scheduleBufferingRecovery(
                            `nonfatal:${detail || "unknown"}`,
                        );
                        void tryRecoverHlsPlayback(
                            `nonfatal:${detail || "unknown"}`,
                        );
                    }
                    return;
                }

                clearStartupTimer();
                const errorDetail =
                    data.error instanceof Error
                        ? data.error.message
                        : typeof data.error === "string"
                          ? data.error
                          : "";
                const lowerDetail = errorDetail.toLowerCase();
                const canNativeFallback =
                    useHls &&
                    nativeHlsSupported &&
                    !attemptedNativeCodecFallback &&
                    data.details === "bufferAddCodecError" &&
                    (lowerDetail.includes("mp4a.40.1") ||
                        lowerDetail.includes("addsourcebuffer"));
                if (canNativeFallback && videoEl) {
                    attemptedNativeCodecFallback = true;
                    dispatch("hls_info", {
                        type: "hls_info",
                        message:
                            "[hls.js] codec fallback -> trying native-src for unsupported mp4a.40.1",
                    });
                    destroyHls();
                    videoEl.src = url;
                    videoEl.load();
                    void safeAutoplay(nonce, "native-src-fallback");
                    return;
                }
                const messageParts = [
                    `[hls.js] ${data.details ?? "Fatal HLS playback error"}`,
                ];
                if (errorDetail) messageParts.push(errorDetail);
                dispatch("fatal_hls", {
                    type: "fatal_hls",
                    message: messageParts.join(" | "),
                    detail: data,
                });
            });

            hlsInstance.on(Hls.Events.MEDIA_ATTACHED, () => {
                if (nonce !== attachNonce) return;
                hlsInstance?.loadSource(url);
            });

            hlsInstance.on(Hls.Events.LEVEL_LOADED, (_, data) => {
                if (nonce !== attachNonce) return;
                const details = data.details;
                dispatch("hls_info", {
                    type: "hls_info",
                    message: `[hls.js] level_loaded live=${String(details?.live ?? false)} fragments=${details?.fragments?.length ?? 0} endSN=${details?.endSN ?? -1}`,
                });
            });

            hlsInstance.on(Hls.Events.FRAG_LOADED, (_, data) => {
                if (nonce !== attachNonce) return;
                dispatch("hls_info", {
                    type: "hls_info",
                    message: `[hls.js] frag_loaded sn=${data.frag?.sn ?? "na"} level=${data.frag?.level ?? "na"}`,
                });
            });

            hlsInstance.on(Hls.Events.MANIFEST_PARSED, (_, data) => {
                if (nonce !== attachNonce) return;
                const levels =
                    (
                        data as {
                            levels?: Array<{
                                videoCodec?: string;
                                audioCodec?: string;
                            }>;
                        }
                    ).levels ?? [];
                let remappedAudioCodecs = 0;
                for (const level of levels) {
                    const normalized = normalizeAudioCodec(level.audioCodec);
                    if (normalized && normalized !== level.audioCodec) {
                        level.audioCodec = normalized;
                        remappedAudioCodecs += 1;
                    }
                }
                if (remappedAudioCodecs > 0) {
                    dispatch("hls_info", {
                        type: "hls_info",
                        message: `[hls.js] audio_codec_remap count=${remappedAudioCodecs} from=mp4a.40.1 to=mp4a.40.2`,
                    });
                }
                dispatch("hls_info", {
                    type: "hls_info",
                    message: `[hls.js] manifest_parsed levels=${levels.length}`,
                });
                const supportedLevel = firstSupportedHlsLevel(levels);
                if (levels.length > 0 && supportedLevel === null) {
                    clearStartupTimer();
                    dispatch("fatal_hls", {
                        type: "fatal_hls",
                        message:
                            "[hls.js] bufferAddCodecError | No compatible codec level found for this stream",
                    });
                    return;
                }
                if (supportedLevel !== null && hlsInstance) {
                    hlsInstance.nextLevel = supportedLevel;
                    hlsInstance.loadLevel = supportedLevel;
                }
                hlsInstance?.startLoad(-1);
                void safeAutoplay(nonce, "hls.js");
            });

            hlsInstance.attachMedia(videoEl);
            return;
        }

        videoEl.src = url;
        videoEl.load();
        await safeAutoplay(nonce, "native-src");
    }

    function handleProviderChange(value: string) {
        dispatch("providerChange", value);
    }

    function setPlaybackRate(rate: number) {
        playbackRate = rate;
        if (videoEl) videoEl.playbackRate = rate;
    }

    function setFitMode(mode: "contain" | "cover") {
        fitMode = mode;
    }

    function clearBufferingRecoveryTimer() {
        if (!bufferingRecoveryTimer) return;
        clearTimeout(bufferingRecoveryTimer);
        bufferingRecoveryTimer = null;
    }

    function resetHlsRecoveryState() {
        hlsRecoveryAttempts = 0;
        hlsRecoveryWindowStart = 0;
        lastHlsRecoveryAt = 0;
        fragParsingErrorCount = 0;
        fragParsingWindowStart = 0;
        clearBufferingRecoveryTimer();
    }

    function noteFragParsingError(): number {
        const now = Date.now();
        if (now - fragParsingWindowStart > FRAG_PARSING_WINDOW_MS) {
            fragParsingWindowStart = now;
            fragParsingErrorCount = 0;
        }
        fragParsingErrorCount += 1;
        return fragParsingErrorCount;
    }

    function isTimeBuffered(time: number, tolerance = 0.25): boolean {
        if (!videoEl || !Number.isFinite(time) || time < 0) return false;
        const ranges = videoEl.buffered;
        for (let index = 0; index < ranges.length; index += 1) {
            const start = ranges.start(index);
            const end = ranges.end(index);
            if (time >= start - tolerance && time <= end + tolerance)
                return true;
        }
        return false;
    }

    function lastBufferedEnd(): number {
        if (!videoEl || videoEl.buffered.length === 0) return Number.NaN;
        let maxEnd = Number.NaN;
        for (let index = 0; index < videoEl.buffered.length; index += 1) {
            const end = videoEl.buffered.end(index);
            if (!Number.isFinite(maxEnd) || end > maxEnd) maxEnd = end;
        }
        return maxEnd;
    }

    function alignPlaybackToBufferedRange(): boolean {
        if (!videoEl || videoEl.buffered.length === 0) return false;
        const current = Number.isFinite(videoEl.currentTime)
            ? videoEl.currentTime
            : 0;
        let nextStart = Number.NaN;
        let previousEnd = Number.NaN;

        for (let index = 0; index < videoEl.buffered.length; index += 1) {
            const start = videoEl.buffered.start(index);
            const end = videoEl.buffered.end(index);
            if (current >= start - 0.1 && current <= end + 0.1) {
                return true;
            }
            if (
                start > current &&
                (!Number.isFinite(nextStart) || start < nextStart)
            ) {
                nextStart = start;
            }
            if (
                end < current &&
                (!Number.isFinite(previousEnd) || end > previousEnd)
            ) {
                previousEnd = end;
            }
        }

        if (Number.isFinite(nextStart)) {
            videoEl.currentTime = Math.max(0, nextStart + 0.05);
            return true;
        }

        if (Number.isFinite(previousEnd)) {
            videoEl.currentTime = Math.max(0, previousEnd - 0.2);
            return true;
        }

        return false;
    }

    async function tryRecoverHlsPlayback(
        reason: string,
        options?: { recoverMediaError?: boolean },
    ) {
        if (!videoEl || !hlsInstance) return;

        const now = Date.now();
        if (now - hlsRecoveryWindowStart > HLS_RECOVERY_WINDOW_MS) {
            hlsRecoveryWindowStart = now;
            hlsRecoveryAttempts = 0;
        }
        if (now - lastHlsRecoveryAt < HLS_RECOVERY_COOLDOWN_MS) return;

        lastHlsRecoveryAt = now;
        hlsRecoveryAttempts += 1;

        if (hlsRecoveryAttempts > HLS_MAX_RECOVERY_ATTEMPTS) {
            playerState = "error";
            dispatch("fatal_hls", {
                type: "fatal_hls",
                message: `[hls.js] recovery_exhausted reason=${reason}`,
            });
            return;
        }

        const currentTime = Number.isFinite(videoEl.currentTime)
            ? videoEl.currentTime
            : 0;
        let startLoadAt =
            Number.isFinite(currentTime) && currentTime >= 0 ? currentTime : -1;
        if (!isTimeBuffered(currentTime)) {
            const bufferedEnd = lastBufferedEnd();
            if (
                Number.isFinite(bufferedEnd) &&
                bufferedEnd > 0 &&
                currentTime > bufferedEnd + 0.5
            ) {
                videoEl.currentTime = Math.max(0, bufferedEnd - 0.2);
                startLoadAt = Math.max(0, videoEl.currentTime - 0.5);
            }
        }
        if (reason.includes("frag_parsing_error")) {
            startLoadAt = Math.max(0, startLoadAt + 0.6);
        }

        dispatch("hls_info", {
            type: "hls_info",
            message: `[hls.js] recovery attempt=${hlsRecoveryAttempts} reason=${reason}`,
        });

        if (options?.recoverMediaError) {
            dispatch("hls_info", {
                type: "hls_info",
                message: `[hls.js] recoverMediaError reason=${reason}`,
            });
            hlsInstance.recoverMediaError();
        }

        hlsInstance.stopLoad();
        hlsInstance.startLoad(startLoadAt);
        try {
            await videoEl.play();
        } catch {
            // best effort resume
        }
    }

    function scheduleBufferingRecovery(reason: string) {
        if (!pathIsHls(playbackUrl ?? "", sourceKind) || !hlsInstance) return;
        clearBufferingRecoveryTimer();
        bufferingRecoveryTimer = setTimeout(() => {
            if (playerState === "buffering") {
                void tryRecoverHlsPlayback(`buffering_timeout:${reason}`);
            }
        }, 2000);
    }

    function isVideoPlaying(): boolean {
        return Boolean(videoEl && !videoEl.paused && !videoEl.ended);
    }

    function onVideoTimeUpdate() {
        if (!videoEl) return;
        currentTimeSec = Number.isFinite(videoEl.currentTime)
            ? videoEl.currentTime
            : 0;
        durationSec = Number.isFinite(videoEl.duration) ? videoEl.duration : 0;
        seekPercent =
            durationSec > 0 ? (currentTimeSec / durationSec) * 100 : 0;
        updateBufferedPercent();
        if (isVideoPlaying()) {
            playerState = "playing";
            clearBufferingRecoveryTimer();
        }
    }

    function onVideoProgress() {
        updateBufferedPercent();
    }

    function updateBufferedPercent() {
        if (
            !videoEl ||
            !Number.isFinite(durationSec) ||
            durationSec <= 0 ||
            videoEl.buffered.length === 0
        ) {
            bufferedPercent = 0;
            return;
        }

        const current = Number.isFinite(videoEl.currentTime)
            ? videoEl.currentTime
            : 0;
        let bufferedEnd = 0;

        for (let index = 0; index < videoEl.buffered.length; index += 1) {
            const start = videoEl.buffered.start(index);
            const end = videoEl.buffered.end(index);
            if (current >= start - 0.1 && current <= end + 0.1) {
                bufferedEnd = Math.max(bufferedEnd, end);
                break;
            }
            if (end < current) {
                bufferedEnd = Math.max(bufferedEnd, end);
            }
        }

        const rawPercent = (bufferedEnd / durationSec) * 100;
        bufferedPercent = Math.min(
            100,
            Math.max(seekPercent, Number.isFinite(rawPercent) ? rawPercent : 0),
        );
    }

    function seekTrackStyle(): string {
        const clamped = Math.min(100, Math.max(0, seekPercent));
        const buffered = Math.min(100, Math.max(clamped, bufferedPercent));
        return `--seek-fill: ${clamped}%; --seek-buffer: ${buffered}%;`;
    }

    function volumeTrackStyle(): string {
        const percent = Math.min(100, Math.max(0, volumeLevel * 100));
        return `--seek-fill: ${percent}%;`;
    }

    function onSeekInput(event: Event) {
        const target = event.currentTarget as HTMLInputElement;
        const nextPercent = Number(target.value);
        seekPercent = Number.isFinite(nextPercent)
            ? Math.min(100, Math.max(0, nextPercent))
            : seekPercent;
        if (!videoEl || !Number.isFinite(durationSec) || durationSec <= 0)
            return;
        videoEl.currentTime = (seekPercent / 100) * durationSec;
        if (!isTimeBuffered(videoEl.currentTime)) {
            playerState = "buffering";
            scheduleBufferingRecovery("seek_unbuffered");
            void tryRecoverHlsPlayback("seek_unbuffered");
            return;
        }
        if (!videoEl.paused) playerState = "playing";
    }

    function onVolumeInput(event: Event) {
        const target = event.currentTarget as HTMLInputElement;
        const next = Number(target.value);
        if (!videoEl || !Number.isFinite(next)) return;
        volumeLevel = Math.min(1, Math.max(0, next));
        videoEl.volume = volumeLevel;
        muted = volumeLevel <= 0.001;
        videoEl.muted = muted;
    }

    function toggleMute() {
        if (!videoEl) return;
        if (muted || videoEl.muted || volumeLevel <= 0.001) {
            muted = false;
            videoEl.muted = false;
            if (volumeLevel <= 0.001) {
                volumeLevel = 1;
                videoEl.volume = 1;
            }
            return;
        }
        muted = true;
        videoEl.muted = true;
    }

    function seekBy(deltaSeconds: number) {
        if (!videoEl) return;
        const target = videoEl.currentTime + deltaSeconds;
        const max =
            Number.isFinite(durationSec) && durationSec > 0
                ? durationSec
                : target;
        videoEl.currentTime = Math.min(max, Math.max(0, target));
        if (!isTimeBuffered(videoEl.currentTime)) {
            playerState = "buffering";
            scheduleBufferingRecovery("seek_skip_unbuffered");
            void tryRecoverHlsPlayback("seek_skip_unbuffered");
            return;
        }
        if (!videoEl.paused) playerState = "playing";
    }

    async function togglePlayPause() {
        if (!videoEl) return;
        if (videoEl.paused || videoEl.ended) {
            playerState = "buffering";
            try {
                await videoEl.play();
            } catch {
                // user gesture gating, keep silent
                if (videoEl.paused) playerState = "paused";
            }
            return;
        }
        playerState = "paused";
        videoEl.pause();
    }

    async function toggleFullscreen() {
        if (!playerShellEl || typeof document === "undefined") return;
        try {
            if (document.fullscreenElement) {
                await document.exitFullscreen();
            } else {
                await playerShellEl.requestFullscreen();
            }
        } catch {
            // Fullscreen is best-effort.
        }
    }

    function clearFullscreenUiTimer() {
        if (!fullscreenUiTimer) return;
        clearTimeout(fullscreenUiTimer);
        fullscreenUiTimer = null;
    }

    function onFullscreenActivity() {
        if (!isFullscreen) return;
        fullscreenUiVisible = true;
        clearFullscreenUiTimer();
        fullscreenUiTimer = setTimeout(() => {
            fullscreenUiVisible = false;
        }, FULLSCREEN_UI_HIDE_DELAY_MS);
    }

    function syncFullscreenState() {
        if (typeof document === "undefined") {
            isFullscreen = false;
            return;
        }
        const active = document.fullscreenElement;
        isFullscreen = Boolean(
            active &&
                playerShellEl &&
                (active === playerShellEl || playerShellEl.contains(active)),
        );
        fullscreenUiVisible = true;
        if (isFullscreen) {
            onFullscreenActivity();
        } else {
            clearFullscreenUiTimer();
        }
    }

    function onGlobalKeydown(event: KeyboardEvent) {
        const target = event.target as HTMLElement | null;
        const tag = target?.tagName?.toLowerCase();
        if (tag === "input" || tag === "textarea" || tag === "select") return;

        if (event.key.toLowerCase() === "f") {
            event.preventDefault();
            void toggleFullscreen();
        }
        if (event.key === "Escape") {
            settingsOpen = false;
        }
    }

    function onGlobalPointerDown(event: PointerEvent) {
        onFullscreenActivity();
        if (!settingsOpen) return;
        const target = event.target as Node;
        if (
            !settingsPanelEl?.contains(target) &&
            !settingsButtonEl?.contains(target)
        ) {
            settingsOpen = false;
        }
    }

    function onGlobalMouseMove() {
        onFullscreenActivity();
    }

    function onVideoPlay() {
        playerState = "playing";
        clearBufferingRecoveryTimer();
        hlsRecoveryAttempts = 0;
        onFullscreenActivity();
        dispatch("play");
    }

    function onVideoReady() {
        clearStartupTimer();
        if (videoEl) {
            videoEl.playbackRate = playbackRate;
            videoEl.volume = volumeLevel;
            videoEl.muted = muted;
        }
        onVideoTimeUpdate();
        playerState = isVideoPlaying() ? "playing" : "paused";
        clearBufferingRecoveryTimer();
        if (playerState === "playing") {
            hlsRecoveryAttempts = 0;
        }
        onFullscreenActivity();
        dispatch("ready");
    }

    function onVideoPause() {
        if (!videoEl?.ended) {
            playerState = "paused";
        }
        clearBufferingRecoveryTimer();
        onFullscreenActivity();
    }

    function onVideoWaiting() {
        if (videoEl?.paused && !videoEl.seeking) {
            playerState = "paused";
            return;
        }
        playerState = "buffering";
        scheduleBufferingRecovery("video_waiting");
        onFullscreenActivity();
    }

    function onVideoSeeking() {
        if (!videoEl) return;
        if (!isTimeBuffered(videoEl.currentTime)) {
            playerState = "buffering";
            scheduleBufferingRecovery("video_seeking");
        }
    }

    function onVideoSeeked() {
        if (!videoEl) return;
        if (videoEl.paused) {
            playerState = "paused";
            clearBufferingRecoveryTimer();
            return;
        }
        playerState = isTimeBuffered(videoEl.currentTime)
            ? "playing"
            : "buffering";
        if (playerState === "buffering") {
            scheduleBufferingRecovery("video_seeked");
        } else {
            clearBufferingRecoveryTimer();
        }
    }

    function onVideoEnded() {
        playerState = "paused";
        clearBufferingRecoveryTimer();
        onFullscreenActivity();
        dispatch("ended");
        if (
            autoNext &&
            Number.isFinite(nextEpisodeNumber) &&
            (nextEpisodeNumber ?? 0) > 0
        ) {
            dispatch("episodeSelect", nextEpisodeNumber);
        }
    }

    function selectAdjacentEpisode(direction: "prev" | "next") {
        const episode = findAdjacentEpisode(
            episodeNumbers,
            selectedNumber,
            direction,
        );
        if (!episode) return;
        dispatch("episodeSelect", episode);
    }

    function onVideoError(event: Event) {
        clearStartupTimer();
        clearBufferingRecoveryTimer();
        playerState = "error";
        onFullscreenActivity();
        const stage = pathIsHls(playbackUrl ?? "", sourceKind)
            ? "hls-video"
            : "native-video";
        const code = describeVideoErrorCode(videoEl?.error?.code);
        dispatch("media_error", {
            type: "media_error",
            message: `[${stage}] Media element playback error code=${code}`,
            detail: event,
        });
    }

    onMount(() => {
        document.addEventListener("fullscreenchange", syncFullscreenState);
        document.addEventListener("keydown", onGlobalKeydown);
        document.addEventListener("pointerdown", onGlobalPointerDown);
        document.addEventListener("mousemove", onGlobalMouseMove);
        syncFullscreenState();
    });

    onDestroy(() => {
        document.removeEventListener("fullscreenchange", syncFullscreenState);
        document.removeEventListener("keydown", onGlobalKeydown);
        document.removeEventListener("pointerdown", onGlobalPointerDown);
        document.removeEventListener("mousemove", onGlobalMouseMove);
        clearFullscreenUiTimer();
        teardownPlayback(true);
    });
</script>

<div bind:this={playerShellEl} class="flex min-h-0 flex-col gap-2">
    {#if !isFullscreen}
        <div class="flex items-start justify-between gap-3 px-0.5 py-1">
            <div class="grid min-w-0 gap-0.5">
                <p
                    class="truncate text-[0.99rem] font-medium leading-tight text-white"
                >
                    {episodeTitle ||
                        (selectedEpisode
                            ? `Episode ${selectedEpisode.number}`
                            : "Select Episode")}
                </p>
                <p class="truncate text-[0.78rem] leading-tight text-white/70">
                    {selectedEpisode
                        ? `Episode ${selectedEpisode.number}`
                        : "Episode -"} | {animeTitle}
                </p>
            </div>

            {#if providerOptions.length}
                <div class="shrink-0">
                    <SelectPicker
                        items={providerOptions.map((option) => ({
                            value: option.value,
                            label: option.label,
                        }))}
                        value={provider}
                        onChange={handleProviderChange}
                        triggerClass="h-8 w-[176px] rounded-[10px] px-3 text-[0.8rem] font-medium text-white/88"
                        contentClass="min-w-[176px]"
                    />
                </div>
            {/if}
        </div>
    {/if}

    <div
        class="group/player relative overflow-hidden bg-black shadow-[0_0_0_1px_rgba(255,255,255,0.08),0_0_28px_rgba(255,255,255,0.07),0_0_64px_rgba(255,255,255,0.04)]
               {isFullscreen
            ? 'min-h-[320px] md:min-h-[420px] xl:min-h-0 xl:flex-1'
            : 'aspect-video w-full min-h-0'}
               {isFullscreen && !fullscreenUiVisible ? 'cursor-none' : ''}"
    >
        <video
            bind:this={videoEl}
            class="h-full w-full bg-black"
            style:object-fit={fitMode}
            playsinline
            preload="metadata"
            crossorigin="anonymous"
            on:play={onVideoPlay}
            on:pause={onVideoPause}
            on:waiting={onVideoWaiting}
            on:seeking={onVideoSeeking}
            on:seeked={onVideoSeeked}
            on:timeupdate={onVideoTimeUpdate}
            on:progress={onVideoProgress}
            on:loadedmetadata={onVideoReady}
            on:playing={onVideoReady}
            on:canplay={onVideoReady}
            on:ended={onVideoEnded}
            on:error={onVideoError}
        ></video>

        {#if (playerState === "idle" || playerState === "buffering" || loading) && (!isFullscreen || fullscreenUiVisible)}
            <div class="absolute inset-0 grid place-items-center bg-black/45">
                {#if playerState === "buffering" || loading}
                    <div class="grid place-items-center gap-2">
                        <div
                            class="h-6 w-6 animate-spin rounded-full border-2 border-white/30 border-t-white"
                        ></div>
                        <p class="font-mono text-sm text-white/70">
                            {statusMessage || "Loading episode..."}
                        </p>
                    </div>
                {:else}
                    <p class="font-mono text-sm text-white/70">
                        Select an episode to start playback.
                    </p>
                {/if}
            </div>
        {/if}

        <div
            class="pointer-events-none absolute inset-x-0 bottom-0 z-20 h-44 bg-gradient-to-t from-black/94 via-black/58 to-transparent transition-opacity duration-200
                   {isFullscreen
                ? fullscreenUiVisible
                    ? 'opacity-100'
                    : 'opacity-0'
                : 'opacity-0 group-hover/player:opacity-100 group-focus-within/player:opacity-100'}"
        ></div>

        <div
            class="absolute inset-x-0 bottom-0 z-30 px-3 pb-2 pt-2.5 transition-opacity duration-200
                   {isFullscreen
                ? fullscreenUiVisible
                    ? 'opacity-100'
                    : 'pointer-events-none opacity-0'
                : 'pointer-events-none opacity-0 group-hover/player:pointer-events-auto group-hover/player:opacity-100 group-focus-within/player:pointer-events-auto group-focus-within/player:opacity-100'}"
        >
            <div class="relative">
                <input
                    class="nm-slider nm-seek h-4 w-full cursor-pointer appearance-none bg-transparent"
                    style={seekTrackStyle()}
                    type="range"
                    min="0"
                    max="100"
                    step="0.1"
                    value={seekPercent}
                    on:input={onSeekInput}
                />
            </div>

            <div
                class="mt-0.5 flex items-center justify-between text-[0.68rem] text-white/84"
            >
                <span>{formatPlaybackTime(currentTimeSec)}</span>
                <span>{formatPlaybackTime(durationSec)}</span>
            </div>

            <div class="mt-2 flex items-center justify-between gap-3">
                <div class="flex items-center gap-2">
                    <button
                        type="button"
                        class="inline-flex h-8 w-8 items-center justify-center rounded-[8px] border-0 bg-transparent p-0 text-white/95 hover:text-white"
                        aria-label={muted ? "Unmute" : "Mute"}
                        on:click={toggleMute}
                    >
                        {#if muted}
                            <SpeakerSlashIcon size={16} weight="bold" />
                        {:else}
                            <SpeakerHighIcon size={16} weight="bold" />
                        {/if}
                    </button>
                    <input
                        class="nm-slider nm-volume h-4 w-[84px] cursor-pointer appearance-none bg-transparent"
                        style={volumeTrackStyle()}
                        type="range"
                        min="0"
                        max="1"
                        step="0.01"
                        value={volumeLevel}
                        on:input={onVolumeInput}
                    />
                </div>

                <div class="flex items-center gap-2">
                    <button
                        type="button"
                        class="inline-flex h-8 w-8 items-center justify-center rounded-[8px] border-0 bg-transparent p-0 text-white/95 hover:text-white disabled:opacity-45"
                        aria-label="Seek 10 seconds back"
                        on:click={() => seekBy(-10)}
                    >
                        <ClockCounterClockwiseIcon size={18} weight="bold" />
                    </button>
                    <button
                        type="button"
                        class="inline-flex h-9 w-9 items-center justify-center rounded-full border-0 bg-transparent p-0 text-white/95 hover:text-white disabled:opacity-45"
                        aria-label={showPauseIcon ? "Pause" : "Play"}
                        disabled={playerState === "idle" && !selectedSource}
                        on:click={togglePlayPause}
                    >
                        {#if showPauseIcon}
                            <PauseIcon size={17} weight="fill" />
                        {:else}
                            <PlayIcon size={17} weight="fill" />
                        {/if}
                    </button>
                    <button
                        type="button"
                        class="inline-flex h-8 w-8 items-center justify-center rounded-[8px] border-0 bg-transparent p-0 text-white/95 hover:text-white disabled:opacity-45"
                        aria-label="Seek 10 seconds forward"
                        on:click={() => seekBy(10)}
                    >
                        <ClockClockwiseIcon size={18} weight="bold" />
                    </button>
                </div>

                <div class="relative flex items-center gap-1.5">
                    <button
                        type="button"
                        class="inline-flex h-8 w-8 items-center justify-center rounded-[8px] border-0 bg-transparent p-0 {theatreMode
                            ? 'text-white'
                            : 'text-white/90 hover:text-white'}"
                        aria-label="Toggle theatre mode"
                        on:click={() => dispatch("toggleTheatre")}
                    >
                        <RectangleIcon size={15} weight="bold" />
                    </button>
                    <button
                        type="button"
                        class="inline-flex h-8 w-8 items-center justify-center rounded-[8px] border-0 bg-transparent p-0 text-white/95 hover:text-white"
                        aria-label={isFullscreen
                            ? "Exit fullscreen"
                            : "Enter fullscreen"}
                        on:click={toggleFullscreen}
                    >
                        {#if isFullscreen}
                            <ArrowsOutIcon size={16} weight="bold" />
                        {:else}
                            <CornersOutIcon size={16} weight="bold" />
                        {/if}
                    </button>
                    <button
                        type="button"
                        bind:this={settingsButtonEl}
                        class="inline-flex h-8 w-8 items-center justify-center rounded-[8px] border-0 bg-transparent p-0 text-white/95 hover:text-white"
                        aria-label="Open player settings"
                        aria-expanded={settingsOpen}
                        on:click={() => (settingsOpen = !settingsOpen)}
                    >
                        <DotsThreeVerticalIcon size={16} weight="bold" />
                    </button>
                    {#if settingsOpen}
                        <div
                            bind:this={settingsPanelEl}
                            class="absolute bottom-[calc(100%+0.6rem)] right-0 z-[50] grid w-[260px] gap-2 rounded-[12px] bg-[rgba(20,22,28,0.76)] p-2.5 shadow-[0_10px_28px_rgba(0,0,0,0.45)] backdrop-blur-[20px]"
                            role="menu"
                            aria-label="Player settings"
                        >
                            <div class="grid gap-1">
                                <p
                                    class="px-1 text-[0.68rem] font-semibold uppercase tracking-[0.06em] text-white/62"
                                >
                                    Playback Speed
                                </p>
                                <div class="grid grid-cols-3 gap-1">
                                    {#each playbackRates as rate}
                                        <button
                                            type="button"
                                            class="inline-flex h-8 items-center justify-center rounded-[8px] text-[0.74rem] font-medium {playbackRate ===
                                            rate
                                                ? 'bg-white/18 text-white'
                                                : 'bg-white/8 text-white/78 hover:bg-white/12'}"
                                            on:click={() =>
                                                setPlaybackRate(rate)}
                                        >
                                            {rate.toFixed(
                                                rate % 1 === 0 ? 0 : 2,
                                            )}x
                                        </button>
                                    {/each}
                                </div>
                            </div>

                            <div class="grid gap-1">
                                <p
                                    class="px-1 text-[0.68rem] font-semibold uppercase tracking-[0.06em] text-white/62"
                                >
                                    Quality
                                </p>
                                <div class="grid grid-cols-2 gap-1">
                                    {#if sources.length === 0}
                                        <button
                                            type="button"
                                            class="inline-flex h-8 items-center justify-center rounded-[8px] bg-white/8 text-[0.74rem] text-white/45"
                                            disabled
                                        >
                                            Auto
                                        </button>
                                        <button
                                            type="button"
                                            class="inline-flex h-8 items-center justify-center rounded-[8px] bg-white/8 text-[0.74rem] text-white/45"
                                            disabled
                                        >
                                            None
                                        </button>
                                    {:else}
                                        {#each sources as source}
                                            <button
                                                type="button"
                                                class="inline-flex h-8 items-center justify-center rounded-[8px] px-2 text-[0.74rem] {selectedSource?.url ===
                                                source.url
                                                    ? 'bg-white/18 text-white'
                                                    : 'bg-white/8 text-white/78 hover:bg-white/12'}"
                                                on:click={() =>
                                                    dispatch(
                                                        "sourceChange",
                                                        source,
                                                    )}
                                            >
                                                <span class="truncate"
                                                    >{source.quality}</span
                                                >
                                            </button>
                                        {/each}
                                    {/if}
                                </div>
                            </div>

                            <div class="grid gap-1">
                                <p
                                    class="px-1 text-[0.68rem] font-semibold uppercase tracking-[0.06em] text-white/62"
                                >
                                    Video Mode
                                </p>
                                <div class="grid grid-cols-2 gap-1">
                                    <button
                                        type="button"
                                        class="inline-flex h-8 items-center justify-center rounded-[8px] text-[0.74rem] {fitMode ===
                                        'contain'
                                            ? 'bg-white/18 text-white'
                                            : 'bg-white/8 text-white/78 hover:bg-white/12'}"
                                        on:click={() => setFitMode("contain")}
                                    >
                                        Fit
                                    </button>
                                    <button
                                        type="button"
                                        class="inline-flex h-8 items-center justify-center rounded-[8px] text-[0.74rem] {fitMode ===
                                        'cover'
                                            ? 'bg-white/18 text-white'
                                            : 'bg-white/8 text-white/78 hover:bg-white/12'}"
                                        on:click={() => setFitMode("cover")}
                                    >
                                        Fill
                                    </button>
                                </div>
                            </div>
                        </div>
                    {/if}
                </div>
            </div>
        </div>
    </div>

    {#if !isFullscreen}
        <div class="mt-1 px-0.5">
            <div
                class="flex w-full items-stretch overflow-hidden border border-[#242424] bg-[#050505]"
            >
                <button
                    type="button"
                    class="inline-flex h-9 flex-1 items-center justify-center gap-1.5 px-0 text-[0.78rem] font-medium transition-colors {autoPlay
                        ? 'bg-[#181818] text-white'
                        : 'bg-[#050505] text-white/76 hover:bg-[#101010]'}"
                    on:click={() => dispatch("toggleAutoPlay")}
                >
                    <PlayIcon size={12} weight="fill" />
                    Auto Play
                </button>
                <span class="w-px self-stretch bg-[#242424]"></span>
                <button
                    type="button"
                    class="inline-flex h-9 flex-1 items-center justify-center gap-1.5 px-0 text-[0.78rem] font-medium transition-colors {autoNext
                        ? 'bg-[#181818] text-white'
                        : 'bg-[#050505] text-white/76 hover:bg-[#101010]'}"
                    on:click={() => dispatch("toggleAutoNext")}
                >
                    <PlayCircleIcon size={13} weight="fill" />
                    Auto Next
                </button>
                <span class="w-px self-stretch bg-[#242424]"></span>
                <button
                    type="button"
                    class="inline-flex h-9 flex-1 items-center justify-center gap-1.5 px-0 text-[0.78rem] font-medium transition-colors {focusMode
                        ? 'bg-[#181818] text-white'
                        : 'bg-[#050505] text-white/76 hover:bg-[#101010]'}"
                    on:click={() => dispatch("toggleFocus")}
                >
                    <CircleHalfIcon size={13} weight="bold" />
                    Focus
                </button>
                <span class="w-px self-stretch bg-[#242424]"></span>
                <button
                    type="button"
                    class="inline-flex h-9 flex-1 items-center justify-center gap-1.5 bg-[#050505] px-0 text-[0.78rem] font-medium text-white/76 transition-colors hover:bg-[#101010] disabled:opacity-45"
                    disabled={!selectedEpisode || !prevEpisodeNumber}
                    on:click={() => selectAdjacentEpisode("prev")}
                >
                    <SkipBackIcon size={13} weight="bold" />
                    Prev
                </button>
                <span class="w-px self-stretch bg-[#242424]"></span>
                <button
                    type="button"
                    class="inline-flex h-9 flex-1 items-center justify-center gap-1.5 bg-[#050505] px-0 text-[0.78rem] font-medium text-white/76 transition-colors hover:bg-[#101010] disabled:opacity-45"
                    disabled={!selectedEpisode || !nextEpisodeNumber}
                    on:click={() => selectAdjacentEpisode("next")}
                >
                    <SkipForwardIcon size={13} weight="bold" />
                    Next
                </button>
            </div>
        </div>
    {/if}

    {#if mediaError}
        <p class="truncate px-0.5 text-xs text-red-400">{mediaError}</p>
    {/if}
</div>

<style>
    .nm-slider {
        --seek-fill: 0%;
        --seek-buffer: 0%;
    }

    .nm-slider::-webkit-slider-runnable-track {
        height: 3px;
        border-radius: 999px;
        background: linear-gradient(
            to right,
            rgba(255, 255, 255, 0.94) 0 var(--seek-buffer),
            rgba(124, 131, 143, 0.36) var(--seek-buffer) 100%
        );
    }

    .nm-slider::-webkit-slider-thumb {
        -webkit-appearance: none;
        appearance: none;
        margin-top: -4.5px;
        width: 12px;
        height: 12px;
        border-radius: 999px;
        border: 0;
        background: #fff;
    }

    .nm-slider::-moz-range-track {
        height: 3px;
        border-radius: 999px;
        background: linear-gradient(
            to right,
            rgba(255, 255, 255, 0.94) 0 var(--seek-buffer),
            rgba(124, 131, 143, 0.36) var(--seek-buffer) 100%
        );
    }

    .nm-slider::-moz-range-progress {
        height: 3px;
        border-radius: 999px;
        background: rgba(255, 255, 255, 0.96);
    }

    .nm-slider::-moz-range-thumb {
        width: 12px;
        height: 12px;
        border-radius: 999px;
        border: 0;
        background: #fff;
    }
</style>