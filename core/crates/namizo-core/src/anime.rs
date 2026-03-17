use anilist::queries::{
    trending::fetch_trending,
    details::fetch_anime_details,
};
use domain::anime::{AnimeSummary, AnimeDetails};

pub async fn get_trending() -> Result<Vec<AnimeSummary>, String> {
    let res = fetch_trending().await.map_err(|e| e.to_string())?;

    let media = res["data"]["Page"]["media"]
        .as_array()
        .ok_or("Invalid response")?;

    let list = media.iter().map(|item| AnimeSummary {
        id: item["id"].as_i64().unwrap() as i32,
        title: item["title"]["romaji"].as_str().unwrap().to_string(),
        cover_image: item["coverImage"]["large"].as_str().unwrap().to_string(),
        score: item["averageScore"].as_f64(),
    }).collect();

    Ok(list)
}

pub async fn get_details(id: i32) -> Result<AnimeDetails, String> {
    let res = fetch_anime_details(id)
        .await
        .map_err(|e| e.to_string())?;

    let media = &res["data"]["Media"];

    Ok(AnimeDetails {
        id: media["id"].as_i64().unwrap() as i32,
        title: media["title"]["romaji"].as_str().unwrap().to_string(),
        description: media["description"].as_str().unwrap_or("").to_string(),
        cover_image: media["coverImage"]["large"].as_str().unwrap().to_string(),
    })
}