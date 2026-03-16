<script lang="ts">
import { Button as BitsButton } from "bits-ui"

export let type: "button" | "submit" | "reset" = "button"
</script>

<BitsButton
  {type}
  class="inline-flex items-center justify-center rounded-md border border-border bg-background px-4 py-2 text-sm font-medium shadow-sm transition hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
>
  <slot />
</BitsButton>
