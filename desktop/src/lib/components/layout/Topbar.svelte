<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import { BellIcon, GearIcon, ListIcon } from "phosphor-svelte";
  import Avatar from "$components/ui/avatar/Avatar.svelte";
  import { ROUTES } from "$lib/constants/routes";
  import SpotlightSearch from "./SpotlightSearch.svelte";

  let { onMenuClick }: { onMenuClick: () => void } = $props();
  let scrolled = $state(false);

  function handleScroll() {
    scrolled = window.scrollY > 10;
  }

  onMount(() => {
    handleScroll();
    window.addEventListener("scroll", handleScroll, { passive: true });
  });

  onDestroy(() => {
    window.removeEventListener("scroll", handleScroll);
  });
</script>

<header
  class={`fixed top-0 left-0 right-0 z-50 flex h-14 items-center justify-between p-4 sm:p-6 transition-all duration-300 ${
    scrolled
      ? "bg-black/80 backdrop-blur-[12px] shadow-[0_12px_30px_rgba(0,0,0,0.42)]"
      : "bg-transparent"
  }`}
>
  <div class="flex items-center gap-3">
    <button
      onclick={onMenuClick}
      class="inline-flex h-9 w-9 items-center justify-center rounded-md transition hover:bg-muted"
    >
      <ListIcon size={20} weight="regular" />
    </button>

    <a href={ROUTES.HOME} class="text-lg font-semibold tracking-tight">Namizo</a>
  </div>

  <div class="flex items-center gap-3">
    <SpotlightSearch />

    <button
      class="inline-flex h-8 w-8 items-center justify-center rounded-md transition hover:bg-muted/30 hover:backdrop-blur-[10px] hover:ring hover:ring-white/10"
    >
      <BellIcon size={20} weight="regular" />
    </button>

    <a
      href={ROUTES.SETTINGS}
      class="inline-flex h-8 w-8 items-center justify-center rounded-md transition hover:bg-muted/30 hover:backdrop-blur-[10px] hover:ring hover:ring-white/10"
    >
      <GearIcon size={20} weight="regular" />
    </a>

    <a
      href={ROUTES.PROFILE}
      class="inline-flex h-8 w-8 items-center justify-center rounded-md transition hover:bg-muted/30 hover:backdrop-blur-[10px] hover:ring hover:ring-white/80"
    >
      <Avatar
        src="https://s4.anilist.co/file/anilistcdn/user/avatar/large/b6893515-s6uKekNdsFgU.jpg"
        alt="User avatar"
        fallback="U"
        class="h-full w-full rounded-md"
      />
    </a>
  </div>
</header>