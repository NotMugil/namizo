<script lang="ts">
import { Command as BitsCommand } from "bits-ui"
</script>

<BitsCommand.Root
  class="flex w-full flex-col rounded-lg border bg-background shadow-md"
>
  <BitsCommand.Input
    placeholder="Search..."
    class="border-b px-3 py-2 text-sm outline-none"
  />

  <BitsCommand.List class="max-h-64 overflow-y-auto p-1">
    <slot />
  </BitsCommand.List>
</BitsCommand.Root>