<script lang="ts">
import { Avatar as BitsAvatar } from "bits-ui"

export let src: string
export let alt = ""
export let fallback = ""
// export let size = "" // w-10 h-10
</script>

<BitsAvatar.Root
  {...$$restProps}
  class={`inline-flex items-center justify-center overflow-hidden bg-muted ${$$restProps.class ?? ""}`}
>
  <BitsAvatar.Image
    {src}
    {alt}
    class="block h-full w-full object-cover"
  />

  <BitsAvatar.Fallback
    class="flex h-full w-full items-center justify-center text-sm font-medium text-muted-foreground object-cover"
  >
    {fallback}
  </BitsAvatar.Fallback>
</BitsAvatar.Root>