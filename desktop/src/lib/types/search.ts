export interface SearchOption {
    value: string;
    label: string;
}

export type SearchPageItem =
    | { key: string; type: "page"; value: number }
    | { key: string; type: "ellipsis" };