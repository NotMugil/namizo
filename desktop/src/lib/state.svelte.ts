export const sidebar = $state({ open: false });
export const signOut = $state({ confirm: false });

export interface BreadcrumbItem {
	label: string;
	href?: string;
}

export const breadcrumb = $state<{ items: BreadcrumbItem[] }>({ items: [] });
