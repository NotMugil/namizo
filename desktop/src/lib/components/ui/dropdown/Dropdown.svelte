<script lang="ts">
import { DropdownMenu as BitsDropdown } from "bits-ui"
</script>

<BitsDropdown.Root>
  <BitsDropdown.Trigger>
    <slot name="trigger" />
  </BitsDropdown.Trigger>

  <BitsDropdown.Content
    sideOffset={6}
    class="min-w-[180px] rounded-md border bg-background p-1 shadow-md"
  >
    <slot />
  </BitsDropdown.Content>
</BitsDropdown.Root>