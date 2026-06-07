<script lang="ts">
	let {
		open = $bindable(false),
		title,
		description = '',
		confirmLabel = 'Confirm',
		cancelLabel = 'Cancel',
		destructive = false,
		onConfirm,
		onCancel
	}: {
		open: boolean;
		title: string;
		description?: string;
		confirmLabel?: string;
		cancelLabel?: string;
		destructive?: boolean;
		onConfirm: () => void;
		onCancel?: () => void;
	} = $props();

	function cancel() {
		open = false;
		onCancel?.();
	}

	function confirm() {
		open = false;
		onConfirm();
	}
</script>

{#if open}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div
		role="dialog"
		aria-modal="true"
		aria-labelledby="confirm-dlg-title"
		tabindex="-1"
		class="fixed inset-0 z-200 flex items-end sm:items-center justify-center p-4 sm:p-0"
		onkeydown={(e) => { if (e.key === 'Escape') cancel(); }}
	>
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<div
			class="absolute inset-0 bg-black/60 backdrop-blur-sm"
			onclick={cancel}
			role="presentation"
		></div>

		<div class="relative w-full sm:max-w-sm rounded-2xl border border-white/12 bg-[#0e0e0e] p-5 shadow-2xl">
			{#if destructive}
				<div class="mb-3.5 flex h-9 w-9 items-center justify-center rounded-full bg-red-500/10">
					<svg width="17" height="17" viewBox="0 0 24 24" fill="none"
						stroke="currentColor" stroke-width="2" stroke-linecap="round" class="text-red-400">
						<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
						<line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
					</svg>
				</div>
			{/if}

			<h2 id="confirm-dlg-title" class="text-[0.92rem] font-semibold text-white mb-1">{title}</h2>
			{#if description}
				<p class="text-[0.82rem] text-white/45 leading-relaxed mb-5">{description}</p>
			{:else}
				<div class="mb-5"></div>
			{/if}

			<div class="flex gap-2.5">
				<button type="button" onclick={cancel}
					class="btn-ghost inline flex-1 rounded-xl py-2.5 text-sm">
					{cancelLabel}
				</button>
				<button type="button" onclick={confirm}
					class="inline flex-1 rounded-xl py-2.5 text-sm font-medium border transition-colors
					       {destructive
					           ? 'border-red-500/25 bg-red-500/12 text-red-300 hover:bg-red-500/22'
					           : 'btn-primary'}">
					{confirmLabel}
				</button>
			</div>
		</div>
	</div>
{/if}
