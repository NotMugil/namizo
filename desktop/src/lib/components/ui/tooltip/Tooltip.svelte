<script lang="ts">
import { Tooltip as BitsTooltip } from "bits-ui"

export let text: string
</script>

<BitsTooltip.Provider>

  <BitsTooltip.Root delayDuration={200}>

    <BitsTooltip.Trigger>
      <slot />
    </BitsTooltip.Trigger>

    <BitsTooltip.Content
      sideOffset={6}
      class="rounded-md bg-black px-3 py-1 text-xs text-white shadow"
    >
      {text}
    </BitsTooltip.Content>

  </BitsTooltip.Root>

</BitsTooltip.Provider>