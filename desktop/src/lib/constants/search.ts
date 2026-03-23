import type { SearchOption } from "$lib/types/search";

export const SEARCH_DEFAULT_SORT = "POPULARITY_DESC";
export const SEARCH_DEFAULT_FORMAT = "all";

export const SEARCH_SORT_OPTIONS: SearchOption[] = [
    { value: "POPULARITY_DESC", label: "Popularity" },
    { value: "SCORE_DESC", label: "Score" },
    { value: "TITLE_ROMAJI", label: "Title A-Z" },
    { value: "EPISODES_DESC", label: "Episodes" },
];

export const SEARCH_FORMAT_OPTIONS: SearchOption[] = [
    { value: "all", label: "All Formats" },
    { value: "TV", label: "TV" },
    { value: "MOVIE", label: "Movie" },
    { value: "OVA", label: "OVA" },
    { value: "ONA", label: "ONA" },
    { value: "SPECIAL", label: "Special" },
    { value: "MUSIC", label: "Music" },
];

export const SEARCH_GENRE_OPTIONS: string[] = [
    "Action",
    "Adventure",
    "Comedy",
    "Drama",
    "Fantasy",
    "Horror",
    "Mahou Shoujo",
    "Mecha",
    "Music",
    "Mystery",
    "Psychological",
    "Romance",
    "Sci-Fi",
    "Slice of Life",
    "Sports",
    "Supernatural",
    "Thriller",
];