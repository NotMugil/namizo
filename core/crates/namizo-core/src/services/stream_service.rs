use std::sync::Arc;
use providers::{AllAnime, AnimePahe, Anizone, Anidap, SourceOptions, StreamProvider};
use domain::{StreamingEpisode, StreamSource, StreamableAnime};

pub struct StreamService {
    allanime:  Arc<AllAnime>,
    animepahe: Arc<AnimePahe>,
    anizone:   Arc<Anizone>,
    anidap:    Arc<Anidap>,
}

impl StreamService {
    pub fn new() -> Self {
        Self {
            allanime:  Arc::new(AllAnime::new()),
            animepahe: Arc::new(AnimePahe::new()),
            anizone:   Arc::new(Anizone::new()),
            anidap:    Arc::new(Anidap::new()),
        }
    }

    fn provider(&self, name: &str) -> Arc<dyn StreamProvider> {
        match name {
            "allanime"  => self.allanime.clone(),
            "animepahe" => self.animepahe.clone(),
            "anizone"   => self.anizone.clone(),
            "anidap"    => self.anidap.clone(),
            _           => self.animepahe.clone(),
        }
    }

    pub async fn search(
        &self,
        provider_name: &str,
        query: &str,
    ) -> Result<Vec<StreamableAnime>, String> {
        self.provider(provider_name)
            .search(query.into())
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn episodes(
        &self,
        provider_name: &str,
        anime: &StreamableAnime,
    ) -> Result<Vec<StreamingEpisode>, String> {
        self.provider(provider_name)
            .get_episodes(anime)
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn sources(
        &self,
        provider_name: &str,
        episode: &StreamingEpisode,
        options: Option<SourceOptions>,
    ) -> Result<Vec<StreamSource>, String> {
        self.provider(provider_name)
            .get_sources(episode, options.as_ref())
            .await
            .map_err(|e| e.to_string())
    }
}