<script lang="ts">
  import LoaderCircleIcon from '@lucide/svelte/icons/loader-circle'

  export let label: string = 'Loading...'
  export let fullscreen: boolean = true
  export let className: string = ''
  export let spinnerClassName: string = 'h-9 w-9'
  export let labelClassName: string = 'font-mono text-sm text-white/65'
</script>

<div
  class={`grid w-full place-items-center ${
    fullscreen ? 'min-h-screen' : 'min-h-[14rem]'
  } ${className}`.trim()}
>
  <div class="flex flex-col items-center gap-3 text-center">
    <LoaderCircleIcon class={`animate-spin text-white/80 ${spinnerClassName}`.trim()} aria-hidden="true" />
    {#if label}
      <p class={labelClassName}>{label}</p>
    {/if}
  </div>
</div>