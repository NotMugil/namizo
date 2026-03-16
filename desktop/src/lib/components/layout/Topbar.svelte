<script lang="ts">
  import { List, Bell, Gear } from "phosphor-svelte";
  import Avatar from "$components/ui/avatar/Avatar.svelte";
  import { ROUTES } from "$lib/constants/routes";

  let { onMenuClick }: { onMenuClick: () => void } = $props();
</script>

<header class="flex items-center justify-between border-b bg-background px-4 py-2 h-14">

  <div class="flex items-center gap-3">

    <button
      onclick={onMenuClick}
      class="inline-flex h-9 w-9 items-center justify-center rounded-md hover:bg-muted transition"
    >
      <List size={20} weight="regular" />
    </button>

    <a href={ROUTES.HOME} class="text-lg font-semibold tracking-tight">Namizo</a>

  </div>

  <div class="flex items-center gap-3">

    <input
      placeholder="Search anime..."
      class="w-64 rounded-md border bg-background px-3 py-1.5 text-sm outline-none focus:ring-2 focus:ring-ring"
    />

    <button
      class="inline-flex h-9 w-9 items-center justify-center rounded-md hover:bg-muted transition"
    >
      <Bell size={20} />
    </button>

    <a
      href={ROUTES.SETTINGS}
      class="inline-flex h-9 w-9 items-center justify-center rounded-md hover:bg-muted transition"
    >
      <Gear size={20} />
    </a>

    <a href={ROUTES.PROFILE} class="rounded-full hover:ring-2 hover:ring-muted transition">
      <Avatar
        src=""
        alt="User avatar"
        fallback="U"
      />
    </a>

  </div>

</header>