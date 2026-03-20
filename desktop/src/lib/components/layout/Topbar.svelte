<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { ListIcon, BellIcon, GearIcon } from "phosphor-svelte";
  import Avatar from "$components/ui/avatar/Avatar.svelte";
  import { ROUTES } from "$lib/constants/routes";

  let { onMenuClick }: { onMenuClick: () => void } = $props();
  let scrolled = $state(false);

  function handleScroll() {
    console.log("scrollY:", window.scrollY);

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
  class={`fixed top-0 left-0 right-0 z-50 flex items-center justify-between p-8 h-14 transition-all duration-300 ${
    scrolled
      ? "bg-black/80 backdrop-blur-[10px] shadow-[0_12px_30px_rgba(0,0,0,0.42)]"
      : "bg-transparent"
  }`}
>
  <div class="flex items-center gap-3">

    <button
      onclick={onMenuClick}
      class="inline-flex h-9 w-9 items-center justify-center rounded-md hover:bg-muted transition"
    >
      <ListIcon size={20} weight="regular" />
    </button>

    <a href={ROUTES.HOME} class="text-lg font-semibold tracking-tight">Namizo</a>

  </div>

  <div class="flex items-center gap-3">

    <input
      placeholder="Search anime..."
      class="w-96 rounded-full border bg-background/70 backdrop-blur-[20px] px-4 py-2 text-sm outline-none focus:ring focus:ring-ring focus:color-muted"
    />

    <button
      class="inline-flex h-8 w-8 items-center justify-center rounded-md hover:bg-muted/30 hover:backdrop-blur-[10px] hover:ring hover:ring-white/10 transition"
    >
      <BellIcon size={20} weight="regular" />
    </button>

    <a
      href={ROUTES.SETTINGS}
      class="inline-flex h-8 w-8 items-center justify-center rounded-md hover:bg-muted/30 hover:backdrop-blur-[10px] hover:ring hover:ring-white/10 transition"
    >
      <GearIcon size={20} weight="regular" />
    </a>

    <a href={ROUTES.PROFILE} 
      class="inline-flex h-8 w-8 items-center justify-center rounded-md  hover:bg-muted/30 hover:backdrop-blur-[10px] hover:ring hover:ring-white/80 transition"
>
      <Avatar
        src="https://s4.anilist.co/file/anilistcdn/user/avatar/large/b6893515-s6uKekNdsFgU.jpg"
        alt="User avatar"
        fallback="U"
        class="w-full h-full rounded-md"
      />
    </a>

  </div>

</header>