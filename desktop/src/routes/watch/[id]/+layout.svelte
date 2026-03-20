<script lang="ts">
  import "$styles/tailwind.css";
  import Topbar from "$components/layout/Topbar.svelte";
  import Sidebar from "$components/layout/Sidebar.svelte";
  import { sidebar } from "$lib/state.svelte";

  let { children } = $props();
</script>

<div class="flex flex-col min-h-screen bg-black text-foreground z-30">
  <Topbar onMenuClick={() => sidebar.open = !sidebar.open} />
  <main class="flex-1">
    {@render children()}
  </main>
</div>

<!-- backdrop -->
<div
  class="fixed inset-0 z-40 bg-background/40 transition-opacity duration-300
         {sidebar.open ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}"
  onclick={() => sidebar.open = false}
></div>

<!-- sidebar -->
<div
  class="sticky top-0 left-0 h-full w-64 z-50 bg-background border-r border-border shadow-xl
         transition-transform duration-300
         {sidebar.open ? 'translate-x-0' : '-translate-x-full'}"
>
  <Sidebar />
</div>
