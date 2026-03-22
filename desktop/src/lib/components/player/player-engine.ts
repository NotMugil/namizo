import Hls from 'hls.js'

export type EngineErrorType = 'startup_error' | 'fatal_hls' | 'media_error'

export interface EngineErrorEvent {
    type: EngineErrorType
    message: string
    detail?: unknown
}

export interface EngineAttachOptions {
    video: HTMLVideoElement
    url: string
    kind: string
    autoPlay: boolean
    playbackRate: number
    onError: (event: EngineErrorEvent) => void
}

export class PlayerEngine {
    private hlsInstance: Hls | null = null
    private attachedVideo: HTMLVideoElement | null = null
    private attachKey = ''
    private attachNonce = 0
    private startupTimer: ReturnType<typeof setTimeout> | null = null
    private cleanupHandlers: Array<() => void> = []

    async attach(options: EngineAttachOptions): Promise<void> {
        const key = `${options.kind}::${options.url}`

        if (this.attachedVideo === options.video && this.attachKey === key) {
            options.video.playbackRate = options.playbackRate
            if (options.autoPlay && options.video.paused && options.video.readyState >= 2) {
                try {
                    await options.video.play()
                } catch (error) {
                    const message = error instanceof Error ? error.message : String(error)
                    if (!message.toLowerCase().includes('notallowed')) {
                        options.onError({
                            type: 'startup_error',
                            message,
                            detail: error,
                        })
                    }
                }
            }
            return
        }

        this.detach(false)
        const nonce = ++this.attachNonce

        this.attachedVideo = options.video
        this.attachKey = key

        const video = options.video
        const clearStartupTimer = () => {
            if (this.startupTimer) {
                clearTimeout(this.startupTimer)
                this.startupTimer = null
            }
        }
        const registerListener = (
            target: HTMLVideoElement,
            event: keyof HTMLMediaElementEventMap,
            handler: EventListenerOrEventListenerObject,
            opts?: boolean | AddEventListenerOptions,
        ) => {
            target.addEventListener(event, handler, opts)
            this.cleanupHandlers.push(() => {
                target.removeEventListener(event, handler, opts)
            })
        }
        const safeAutoplay = async () => {
            if (!options.autoPlay || this.attachNonce !== nonce) return
            try {
                await video.play()
                clearStartupTimer()
            } catch (error) {
                const message = error instanceof Error ? error.message : String(error)
                if (!message.toLowerCase().includes('notallowed')) {
                    clearStartupTimer()
                    options.onError({
                        type: 'startup_error',
                        message,
                        detail: error,
                    })
                }
            }
        }

        try {
            video.pause()
            video.removeAttribute('src')
            video.load()
            video.preload = 'auto'
            video.playbackRate = options.playbackRate

            registerListener(video, 'loadedmetadata', () => {
                if (this.attachNonce !== nonce) return
                video.playbackRate = options.playbackRate
            })
            registerListener(
                video,
                'canplay',
                () => {
                    if (this.attachNonce !== nonce) return
                    clearStartupTimer()
                },
                { once: true },
            )
            registerListener(
                video,
                'playing',
                () => {
                    if (this.attachNonce !== nonce) return
                    clearStartupTimer()
                },
                { once: true },
            )
            if (options.autoPlay) {
                this.startupTimer = setTimeout(() => {
                    if (this.attachNonce !== nonce) return
                    options.onError({
                        type: 'startup_error',
                        message: 'Playback startup timed out',
                    })
                }, 10_000)
            }

            if (options.kind.toLowerCase().includes('hls') && Hls.isSupported()) {
                this.hlsInstance = new Hls({
                    lowLatencyMode: false,
                })

                this.hlsInstance.on(Hls.Events.ERROR, (_, data) => {
                    if (this.attachNonce !== nonce) return
                    if (data.fatal) {
                        clearStartupTimer()
                        options.onError({
                            type: 'fatal_hls',
                            message: data.details ?? 'Fatal HLS playback error',
                            detail: data,
                        })
                    }
                })

                this.hlsInstance.on(Hls.Events.MEDIA_ATTACHED, () => {
                    if (this.attachNonce !== nonce) return
                    this.hlsInstance?.loadSource(options.url)
                })
                this.hlsInstance.on(Hls.Events.MANIFEST_PARSED, () => {
                    if (this.attachNonce !== nonce) return
                    void safeAutoplay()
                })
                this.hlsInstance.attachMedia(video)
            } else {
                video.src = options.url
                registerListener(
                    video,
                    'canplay',
                    () => {
                        void safeAutoplay()
                    },
                    { once: true },
                )
            }

            if (!options.kind.toLowerCase().includes('hls') && options.autoPlay && video.readyState >= 2) {
                await safeAutoplay()
            }
        } catch (error) {
            clearStartupTimer()
            options.onError({
                type: 'startup_error',
                message: error instanceof Error ? error.message : String(error),
                detail: error,
            })
        }
    }

    detach(resetVideo = true): void {
        this.attachNonce += 1

        if (this.startupTimer) {
            clearTimeout(this.startupTimer)
            this.startupTimer = null
        }
        for (const cleanup of this.cleanupHandlers) {
            cleanup()
        }
        this.cleanupHandlers = []

        this.hlsInstance?.destroy()
        this.hlsInstance = null

        if (resetVideo && this.attachedVideo) {
            this.attachedVideo.pause()
            this.attachedVideo.removeAttribute('src')
            this.attachedVideo.load()
        }

        this.attachedVideo = null
        this.attachKey = ''
    }
}