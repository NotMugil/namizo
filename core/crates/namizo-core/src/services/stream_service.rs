use domain::{StreamSource, StreamableAnime, StreamingEpisode};
use providers::{AllAnime, Anidap, AnimePahe, Anizone, SourceOptions, StreamProvider};
use std::sync::Arc;

pub struct StreamService {
    allanime: Arc<AllAnime>,
    animepahe: Arc<AnimePahe>,
    anizone: Arc<Anizone>,
    anidap: Arc<Anidap>,
}

impl StreamService {
    pub fn new() -> Self {
        Self {
            allanime: Arc::new(AllAnime::new()),
            animepahe: Arc::new(AnimePahe::new()),
            anizone: Arc::new(Anizone::new()),
            anidap: Arc::new(Anidap::new()),
        }
    }

    fn provider(&self, name: &str) -> Arc<dyn StreamProvider> {
        match name {
            "allanime" => self.allanime.clone(),
            "animepahe" => self.animepahe.clone(),
            "anizone" => self.anizone.clone(),
            "anidap" => self.anidap.clone(),
            _ => self.animepahe.clone(),
        }
    }

    pub async fn search(
        &self,
        provider_name: &str,
        query: &str,
    ) -> Result<Vec<StreamableAnime>, String> {
        eprintln!(
            "[stream_search] provider={} query={:?}",
            provider_name, query
        );

        let provider = self.provider(provider_name);
        match provider
            .search(query.into())
            .await
        {
            Ok(results) => {
                eprintln!(
                    "[stream_search] provider={} results={}",
                    provider_name,
                    results.len()
                );
                Ok(results)
            }
            Err(error) => {
                eprintln!(
                    "[stream_search] provider={} error={}",
                    provider_name, error
                );
                Err(error.to_string())
            }
        }
    }

    pub async fn episodes(
        &self,
        provider_name: &str,
        anime: &StreamableAnime,
    ) -> Result<Vec<StreamingEpisode>, String> {
        eprintln!(
            "[stream_episodes] provider={} anime_id={} title={:?}",
            provider_name, anime.id, anime.title
        );

        let provider = self.provider(provider_name);
        match provider
            .get_episodes(anime)
            .await
        {
            Ok(episodes) => {
                eprintln!(
                    "[stream_episodes] provider={} anime_id={} episodes={}",
                    provider_name,
                    anime.id,
                    episodes.len()
                );
                Ok(episodes)
            }
            Err(error) => {
                eprintln!(
                    "[stream_episodes] provider={} anime_id={} error={}",
                    provider_name, anime.id, error
                );
                Err(error.to_string())
            }
        }
    }

    pub async fn sources(
        &self,
        provider_name: &str,
        episode: &StreamingEpisode,
        options: Option<SourceOptions>,
    ) -> Result<Vec<StreamSource>, String> {
        eprintln!(
            "[stream_sources] provider={} anime_id={} episode={} source_id={:?} options={:?}",
            provider_name, episode.anime_id, episode.number, episode.source_id, options
        );

        let provider = self.provider(provider_name);
        match provider
            .get_sources(episode, options.as_ref())
            .await
        {
            Ok(sources) => {
                eprintln!(
                    "[stream_sources] provider={} anime_id={} episode={} sources={}",
                    provider_name,
                    episode.anime_id,
                    episode.number,
                    sources.len()
                );
                Ok(sources)
            }
            Err(error) => {
                eprintln!(
                    "[stream_sources] provider={} anime_id={} episode={} error={}",
                    provider_name, episode.anime_id, episode.number, error
                );
                Err(error.to_string())
            }
        }
    }
}