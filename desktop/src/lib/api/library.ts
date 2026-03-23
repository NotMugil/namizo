import { invoke } from "@tauri-apps/api/core";
import type { LibraryEntry, LibraryFacets, LibraryState } from "$lib/types/library";

export async function libraryFetch(state?: LibraryState): Promise<LibraryEntry[]> {
    return invoke("library_fetch", { state: state ?? null });
}

export async function librarySave(entry: LibraryEntry): Promise<LibraryEntry> {
    return invoke("library_save", { entry });
}

export async function libraryRemove(anilistId: number): Promise<void> {
    await invoke("library_remove", { anilistId });
}

export async function libraryProgress(
    anilistId: number,
    episode: number,
    percent: number,
): Promise<void> {
    await invoke("library_progress", { anilistId, episode, percent });
}

export async function libraryResume(): Promise<LibraryEntry[]> {
    return invoke("library_resume");
}

export async function libraryFacets(): Promise<LibraryFacets> {
    return invoke("library_facets");
}