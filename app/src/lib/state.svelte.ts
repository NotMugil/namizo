export const sidebar = $state({ open: false });
export const signOut = $state({ confirm: false });
// Increment after any library write to signal AnimeCards to re-fetch their status
export const libraryVersion = $state({ n: 0 });

// Playback preferences — populated from localStorage on app mount
export const playbackPrefs = $state({ autoplayTrailers: true });

export interface BreadcrumbItem {
	label: string;
	href?: string;
}

export const breadcrumb = $state<{ items: BreadcrumbItem[] }>({ items: [] });
