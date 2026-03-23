<script lang="ts">
  import { cn } from "$lib/utils";

  let {
    value = $bindable(""),
    class: className = "",
    ...restProps
  }: {
    value?: string;
    class?: string;
    [key: string]: unknown;
  } = $props();
</script>

<textarea
  bind:value
  class={cn(
    "flex min-h-[110px] w-full rounded-[10px] border border-white/15 bg-white/8 px-3 py-2 text-sm text-white outline-none placeholder:text-white/40 transition-colors focus:border-white/30",
    className
  )}
  {...restProps}
>
</textarea>