<script lang="ts">
import { Dialog as BitsDialog } from "bits-ui"
</script>

<BitsDialog.Root>
  <BitsDialog.Trigger>
    <slot name="trigger" />
  </BitsDialog.Trigger>

  <BitsDialog.Portal>
    <BitsDialog.Overlay class="fixed inset-0 bg-black/40 backdrop-blur-sm" />

    <BitsDialog.Content
      class="fixed left-1/2 top-1/2 w-[420px] -translate-x-1/2 -translate-y-1/2 rounded-lg border bg-background p-6 shadow-xl"
    >
      <slot />
    </BitsDialog.Content>
  </BitsDialog.Portal>
</BitsDialog.Root>