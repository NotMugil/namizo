<script lang="ts">
import { Tabs as BitsTabs } from "bits-ui"
</script>

<BitsTabs.Root>

  <BitsTabs.List class="flex gap-2 border-b pb-2">
    <slot name="tabs" />
  </BitsTabs.List>

  <slot />

</BitsTabs.Root>