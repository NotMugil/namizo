import type { DiscoverFilters } from "$lib/types/anime";
import type { SearchOption, SearchPageItem } from "$lib/types/search";

export function getSearchColumns(width: number): number {
    if (width >= 1536) return 8;
    if (width >= 1280) return 7;
    if (width >= 1024) return 6;
    if (width >= 768) return 4;
    if (width >= 640) return 3;
    return 2;
}

export function perPageFromWidth(width: number): number {
    return getSearchColumns(width) * 3;
}

export function buildSearchPageItems(
    totalPages: number,
    currentPage: number,
    siblingCount = 1,
): SearchPageItem[] {
    if (totalPages <= 0) return [];
    if (totalPages === 1) {
        return [{ key: "page-1", type: "page", value: 1 }];
    }

    const items: SearchPageItem[] = [];
    items.push({ key: "page-1", type: "page", value: 1 });

    const left = Math.max(2, currentPage - siblingCount);
    const right = Math.min(totalPages - 1, currentPage + siblingCount);

    if (left > 2) {
        items.push({ key: `ellipsis-left-${left}`, type: "ellipsis" });
    }

    for (let value = left; value <= right; value += 1) {
        items.push({ key: `page-${value}`, type: "page", value });
    }

    if (right < totalPages - 1) {
        items.push({ key: `ellipsis-right-${right}`, type: "ellipsis" });
    }

    items.push({ key: `page-${totalPages}`, type: "page", value: totalPages });
    return items;
}

export function buildSearchDiscoverFilters(
    rawQuery: string,
    selectedSort: string,
    selectedFormat: string,
    selectedGenres: string[],
): DiscoverFilters {
    const normalized = rawQuery.trim();
    return {
        search: normalized.length > 0 ? normalized : undefined,
        genres: selectedGenres.length > 0 ? selectedGenres : undefined,
        formats: selectedFormat !== "all" ? [selectedFormat] : undefined,
        sort: [selectedSort],
        is_adult: false,
    };
}

export function buildSearchFilterKey(
    query: string,
    selectedSort: string,
    selectedFormat: string,
    selectedGenres: string[],
    perPage: number,
): string {
    const genresKey = [...selectedGenres].sort((left, right) => left.localeCompare(right)).join(",");
    return `${query.trim()}|${selectedSort}|${selectedFormat}|${genresKey}|${perPage}`;
}

export function selectedGenreLabel(selectedGenres: string[]): string {
    return selectedGenres.length === 0 ? "Genres" : `${selectedGenres.length} selected`;
}

export function findOptionLabel(options: SearchOption[], value: string): string {
    return options.find((option) => option.value === value)?.label ?? value;
}