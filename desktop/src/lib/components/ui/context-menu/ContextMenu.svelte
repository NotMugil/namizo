<script lang="ts">
import { ContextMenu as BitsContextMenu } from "bits-ui"
</script>

<BitsContextMenu.Root>
  <BitsContextMenu.Trigger>
    <slot name="trigger" />
  </BitsContextMenu.Trigger>

  <BitsContextMenu.Content
    class="min-w-[180px] rounded-md border bg-background p-1 shadow-md"
  >
    <slot />
  </BitsContextMenu.Content>
</BitsContextMenu.Root>