<script lang="ts">
import { page } from "$app/stores"
import VideoPlayer from "$lib/components/player/VideoPlayer.svelte"
import EpisodeList from "$lib/components/anime/EpisodeList.svelte"

const animeId = $derived(page.params.animeId)
const episode = $derived(page.params.episode)
</script>

<div class="watch-container">

  <div class="player">
    <VideoPlayer {animeId} {episode} />
  </div>

  <div class="content">

    <div class="details">
      <h2>Episode {episode}</h2>
    </div>

    <div class="episodes">
      <EpisodeList {animeId} currentEpisode={episode}/>
    </div>

  </div>

</div>