import type { AnimeDetails, Episode } from "$lib/types/anime";
import type { JikanEpisode } from "$lib/types/jikan";
import type { TvdbEpisode } from "$lib/types/tvdb";
import type { EpisodeEnrichmentSource } from "$lib/types/details";

type SourceEpisode = TvdbEpisode | JikanEpisode;

function mapSourceEpisodes(
    sourceEpisodes: SourceEpisode[],
    source: EpisodeEnrichmentSource,
): Episode[] {
    if (source === "tvdb") {
        return (sourceEpisodes as TvdbEpisode[])
            .filter((ep) => Number.isFinite(ep.number) && ep.number > 0)
            .map((ep) => ({
                number: ep.number,
                title: ep.title ?? null,
                thumbnail: ep.thumbnail ?? null,
                description: null,
            }));
    }

    return (sourceEpisodes as JikanEpisode[])
        .filter((ep) => Number.isFinite(ep.number) && ep.number > 0)
        .map((ep) => ({
            number: ep.number,
            title: ep.title ?? null,
            thumbnail: null,
            description: null,
        }));
}

export function applyEnrichedEpisodes(
    current: AnimeDetails,
    sourceEpisodes: SourceEpisode[],
    source: EpisodeEnrichmentSource,
    appendMissing = true,
): AnimeDetails {
    const sourceAsEpisodes = mapSourceEpisodes(sourceEpisodes, source);
    const baseEpisodes = current.episodes.length
        ? current.episodes
        : appendMissing
          ? sourceAsEpisodes.sort((a, b) => a.number - b.number)
          : [];

    const merged = new Map<number, Episode>();
    for (const episode of baseEpisodes) {
        merged.set(episode.number, episode);
    }

    for (const episode of sourceAsEpisodes) {
        const existing = merged.get(episode.number);
        if (!existing) {
            if (!appendMissing) continue;
            merged.set(episode.number, episode);
            continue;
        }

        merged.set(episode.number, {
            ...existing,
            title: episode.title ?? existing.title,
            thumbnail: episode.thumbnail ?? existing.thumbnail,
        });
    }

    const mergedEpisodes = Array.from(merged.values()).sort((left, right) => left.number - right.number);
    return {
        ...current,
        episodes: mergedEpisodes.map((episode) => {
            if (source === "tvdb") {
                const match = (sourceEpisodes as TvdbEpisode[]).find(
                    (tvdbEpisode) => tvdbEpisode.number === Number(episode.number),
                );
                if (!match) return episode;
                return {
                    ...episode,
                    title: match.title ?? episode.title,
                    thumbnail: match.thumbnail ?? episode.thumbnail,
                };
            }

            const match = (sourceEpisodes as JikanEpisode[]).find(
                (jikanEpisode) => jikanEpisode.number === Number(episode.number),
            );
            if (!match) return episode;
            return {
                ...episode,
                title: match.title ?? episode.title,
            };
        }),
    };
}

export function resolveEpisodeCount(
    details: AnimeDetails | null,
    fallbackEpisodeCount: number | null,
): number | null {
    const candidates = [
        details?.episode_count ?? null,
        fallbackEpisodeCount,
        details?.episodes.length ?? null,
    ]
        .map((value) => (Number.isFinite(Number(value)) ? Number(value) : 0))
        .filter((value) => value > 0);

    if (candidates.length === 0) return null;
    return Math.max(...candidates);
}

export function formatAnimeStatus(status: string | null): string {
    if (!status) return "";
    return status.charAt(0) + status.slice(1).toLowerCase().replace(/_/g, " ");
}

export function formatAnimeSeason(season: string | null, year: number | null): string {
    if (!season) return "";
    const formatted = season.charAt(0) + season.slice(1).toLowerCase();
    return year ? `${formatted} ${year}` : formatted;
}