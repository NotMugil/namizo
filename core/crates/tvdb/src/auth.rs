use crate::error::TvdbError;
use once_cell::sync::Lazy;
use reqwest::Client;
use serde_json::{Value, json};
use tokio::sync::Mutex;

const AUTH_URL: &str = "https://api4.thetvdb.com/v4/login";
static TOKEN: Lazy<Mutex<Option<String>>> = Lazy::new(|| Mutex::new(None));

pub async fn get_token(client: &Client, api_key: &str) -> Result<String, TvdbError> {
    {
        let lock = TOKEN.lock().await;
        if let Some(token) = &*lock {
            return Ok(token.clone());
        }
    }

    let raw = client
        .post(AUTH_URL)
        .json(&json!({ "apikey": api_key }))
        .send()
        .await?;
    let response: Value = raw.json().await?;

    let token = response["data"]["token"]
        .as_str()
        .ok_or_else(|| TvdbError::Auth("missing token in response".into()))?
        .to_string();

    {
        let mut lock = TOKEN.lock().await;
        *lock = Some(token.clone());
    }

    Ok(token)
}

pub async fn invalidate_token() {
    let mut lock = TOKEN.lock().await;
    *lock = None;
}