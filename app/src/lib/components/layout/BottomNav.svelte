<script lang="ts">
    import { page } from '$app/state'
    import { HouseIcon, CalendarIcon, SquaresFourIcon, BookmarkIcon, UserCircleIcon } from 'phosphor-svelte'
    import { ROUTES } from '$lib/constants/routes'

    const navItems = [
        { href: ROUTES.HOME,     label: 'Home',     Icon: HouseIcon,       exact: true },
        { href: ROUTES.SCHEDULE, label: 'Schedule', Icon: CalendarIcon,    exact: false },
        { href: ROUTES.DISCOVER, label: 'Browse',   Icon: SquaresFourIcon, exact: false },
        { href: ROUTES.LIBRARY,  label: 'My List',  Icon: BookmarkIcon,    exact: false },
        { href: ROUTES.SETTINGS, label: 'You',      Icon: UserCircleIcon,  exact: false },
    ]

    function isActive(href: string, exact: boolean): boolean {
        const path = page.url.pathname
        if (exact) return path === href
        return path === href || path.startsWith(href + '/')
    }
</script>

<nav class="sm:hidden fixed bottom-0 left-0 right-0 z-50 flex h-16 items-stretch
            bg-black/90 backdrop-blur-[14px] border-t border-white/8"
     aria-label="Bottom navigation"
>
    {#each navItems as { href, label, Icon, exact }}
        {@const active = isActive(href, exact)}
        <a
            {href}
            class="flex flex-1 flex-col items-center justify-center gap-1
                   transition-colors
                   {active ? 'text-white' : 'text-white/40'}"
            aria-current={active ? 'page' : undefined}
        >
            <Icon size={22} weight={active ? 'fill' : 'regular'} />
            <span class="text-[10px] font-medium leading-none">{label}</span>
        </a>
    {/each}
</nav>
