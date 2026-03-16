<script lang="ts">
  import { page } from "$app/state";
  import { House, Compass, Bookmark, Calendar, Gear } from "phosphor-svelte";
  import { ROUTES } from "$lib/constants/routes";
  import { sidebar } from "$lib/state.svelte";

  const navLinks = [
    { href: ROUTES.HOME,     label: "Home",     icon: House    },
    { href: ROUTES.DISCOVER, label: "Discover", icon: Compass  },
    { href: ROUTES.LIBRARY,  label: "Library",  icon: Bookmark },
    { href: ROUTES.SCHEDULE, label: "Schedule", icon: Calendar },
  ];

  const settingsActive = $derived(page.url.pathname.startsWith(ROUTES.SETTINGS));

  function close() {
    sidebar.open = false;
  }
</script>

<aside class="w-64 h-full flex flex-col">

  <nav class="flex flex-col gap-1 p-3">
    {#each navLinks as { href, label, icon: Icon }}
      {@const active = page.url.pathname === href}
      <a
        {href}
        onclick={close}
        class="flex items-center gap-3 px-3 py-2 rounded-md transition-colors
               {active
                 ? 'bg-muted text-foreground font-medium'
                 : 'text-muted-foreground hover:bg-muted hover:text-foreground'}"
        aria-current={active ? 'page' : undefined}
      >
        <Icon size={20} weight={active ? "fill" : "regular"} />
        {label}
      </a>
    {/each}
  </nav>

  <div class="mt-auto p-3 border-t border-border">
    <a
      href={ROUTES.SETTINGS}
      onclick={close}
      class="flex items-center gap-3 px-3 py-2 rounded-md transition-colors
             {settingsActive
               ? 'bg-muted text-foreground font-medium'
               : 'text-muted-foreground hover:bg-muted hover:text-foreground'}"
      aria-current={settingsActive ? 'page' : undefined}
    >
      <Gear size={20} weight={settingsActive ? "fill" : "regular"} />
      Settings
    </a>
  </div>

</aside>