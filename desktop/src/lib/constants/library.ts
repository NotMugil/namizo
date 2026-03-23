import type {
    KnownLibraryReleaseStatus,
    LibraryListScope,
    LibrarySectionDef,
    LibrarySortValue,
} from "$lib/types/library";

export const LIBRARY_BANNER_KEY = "namizo.library.anilist.banner.dismissed";
export const LIBRARY_CARD_WIDTH = 200;
export const LIBRARY_CARD_GAP = 16;

export const LIBRARY_DEFAULT_RELEASE_STATUSES: KnownLibraryReleaseStatus[] = [
    "FINISHED",
    "RELEASING",
    "NOT_YET_RELEASED",
];

export const LIBRARY_DEFAULT_SEASONS = ["WINTER", "SPRING", "SUMMER", "FALL"];

export const LIBRARY_SECTION_DEFS: LibrarySectionDef[] = [
    { value: "WATCHING", label: "Watching", dotClass: "bg-emerald-300" },
    { value: "PLANNING", label: "Planning", dotClass: "bg-sky-300" },
    { value: "COMPLETED", label: "Completed", dotClass: "bg-lime-300" },
    { value: "REWATCHING", label: "Rewatching", dotClass: "bg-violet-300" },
    { value: "PAUSED", label: "Paused", dotClass: "bg-amber-300" },
    { value: "DROPPED", label: "Dropped", dotClass: "bg-rose-300" },
];

export const LIBRARY_LIST_TYPE_OPTIONS: Array<{ value: LibraryListScope; label: string }> = [
    { value: "ALL", label: "All Lists" },
    ...LIBRARY_SECTION_DEFS.map((item) => ({ value: item.value, label: item.label })),
];

export const LIBRARY_SORT_OPTIONS: Array<{ value: LibrarySortValue; label: string }> = [
    { value: "A_Z", label: "A-Z" },
    { value: "Z_A", label: "Z-A" },
    { value: "POPULARITY_DESC", label: "Most Popular" },
    { value: "POPULARITY_ASC", label: "Least Popular" },
    { value: "USER_SCORE_DESC", label: "Highest User Score" },
    { value: "USER_SCORE_ASC", label: "Lowest User Score" },
    { value: "RATING_DESC", label: "Highest Rating" },
    { value: "RATING_ASC", label: "Lowest Rating" },
    { value: "PROGRESS_DESC", label: "Highest Progress" },
    { value: "PROGRESS_ASC", label: "Lowest Progress" },
    { value: "OLDEST", label: "Oldest" },
    { value: "NEWEST", label: "Newest" },
];