<script lang="ts">
import { Popover as BitsPopover } from "bits-ui"
</script>

<BitsPopover.Root>

  <BitsPopover.Trigger>
    <slot name="trigger" />
  </BitsPopover.Trigger>

  <BitsPopover.Content
    sideOffset={8}
    class="rounded-md border bg-background p-3 shadow-md"
  >
    <slot />
  </BitsPopover.Content>

</BitsPopover.Root>