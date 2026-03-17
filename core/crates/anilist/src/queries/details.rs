use domain::anime::AnimeDetails;
use crate::{AnilistClient, AnilistError};

pub async fn fetch_details(client: &AnilistClient, id: u32) -> Result<AnimeDetails, AnilistError> {
    client.fetch_details(id).await
}