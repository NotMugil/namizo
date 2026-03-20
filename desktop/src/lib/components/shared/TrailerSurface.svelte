<script lang="ts">
  import { onMount, onDestroy } from "svelte";

  export let image: string;
  export let trailerId: string;
  // Time to let the iframe load and start playing
  export let loadDelay = 800;
  // Extra wait after playback starts for YT branding to fade out
  export let brandingDelay = 1600;
  export let startAt = 5;

  let showVideo = false;
  let timers: ReturnType<typeof setTimeout>[] = [];

  const embedUrl = `https://www.youtube-nocookie.com/embed/${trailerId}?autoplay=1&mute=1&controls=0&loop=1&playlist=${trailerId}&modestbranding=1&rel=0&iv_load_policy=3&fs=0&disablekb=1&playsinline=1&start=${startAt}`;

  onMount(() => {
    const t1 = setTimeout(() => {
      const t2 = setTimeout(() => {
        showVideo = true;
      }, brandingDelay);
      timers.push(t2);
    }, loadDelay);
    timers.push(t1);
  });

  onDestroy(() => {
    timers.forEach(clearTimeout);
  });
</script>

<div class="absolute inset-0 z-0 overflow-hidden bg-black">
  <img
    src={image}
    alt="preview"
    class={`absolute inset-0 w-full h-full object-cover transition-opacity duration-700 ${
      showVideo ? "opacity-0" : "opacity-100"
    }`}
  />

  <iframe
    src={embedUrl}
    title={"Trailer preview"}
    class="absolute top-1/2 left-1/2 z-0 h-[220%] w-[220%] -translate-x-1/2 -translate-y-1/2 pointer-events-none"
    allow="autoplay"
    tabindex="-1"
  ></iframe>
</div>
