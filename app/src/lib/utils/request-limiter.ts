// Global concurrency limiter for external API requests (TVDB, AniList).
// Prevents simultaneous mass requests that trigger 429 rate limits.

const MAX_CONCURRENT = 3;
let active = 0;
const queue: Array<() => void> = [];

function tick() {
    while (queue.length > 0 && active < MAX_CONCURRENT) {
        active++;
        queue.shift()!();
    }
}

export function limitedRequest<T>(fn: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
        queue.push(() => {
            fn()
                .then(resolve, reject)
                .finally(() => { active--; tick(); });
        });
        tick();
    });
}

// Retry wrapper with exponential backoff — for 429 / "too many requests" errors.
export async function withRetry<T>(
    fn: () => Promise<T>,
    maxAttempts = 3,
    baseDelayMs = 800
): Promise<T> {
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
        try {
            return await fn();
        } catch (e) {
            const msg = String(e).toLowerCase();
            const isRateLimit =
                msg.includes('too many') ||
                msg.includes('429') ||
                msg.includes('rate limit') ||
                msg.includes('failed to parse') ||
                msg.includes('rate limit');

            if (isRateLimit && attempt < maxAttempts - 1) {
                // Use a much longer initial delay for rate-limit errors (5s vs 800ms)
                const delay = isRateLimit ? 5000 : baseDelayMs;
                await new Promise(r => setTimeout(r, delay * Math.pow(2, attempt)));
                continue;
            }
            throw e;
        }
    }
    // Unreachable, but TypeScript needs it
    throw new Error('Max retries exceeded');
}

// Combine both: queue + retry for external API calls.
export function throttledApiCall<T>(fn: () => Promise<T>): Promise<T> {
    return limitedRequest(() => withRetry(fn));
}
