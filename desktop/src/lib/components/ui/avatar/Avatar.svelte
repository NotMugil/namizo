<script lang="ts">
import { Avatar as BitsAvatar } from "bits-ui"

export let src: string
export let alt = ""
export let fallback = ""
</script>

<BitsAvatar.Root
  class="inline-flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-muted"
>
  <BitsAvatar.Image
    {src}
    {alt}
    class="h-full w-full object-cover"
  />

  <BitsAvatar.Fallback
    class="flex h-full w-full items-center justify-center text-sm font-medium text-muted-foreground"
  >
    {fallback}
  </BitsAvatar.Fallback>
</BitsAvatar.Root>