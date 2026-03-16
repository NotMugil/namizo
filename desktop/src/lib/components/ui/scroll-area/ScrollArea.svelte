<script lang="ts">
import { ScrollArea as BitsScrollArea } from "bits-ui"
</script>

<BitsScrollArea.Root class="relative h-full w-full overflow-hidden">

  <BitsScrollArea.Viewport class="h-full w-full">
    <slot />
  </BitsScrollArea.Viewport>

  <BitsScrollArea.Scrollbar
    orientation="vertical"
    class="flex w-2 touch-none select-none"
  >
    <BitsScrollArea.Thumb
      class="flex-1 rounded-full bg-muted-foreground/40"
    />
  </BitsScrollArea.Scrollbar>

</BitsScrollArea.Root>