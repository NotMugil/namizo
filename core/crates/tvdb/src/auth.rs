use once_cell::sync::Lazy;
use tokio::sync::Mutex;
use reqwest::Client;
use serde_json::{json, Value};
use crate::error::TvdbError;

const AUTH_URL: &str = "https://api4.thetvdb.com/v4/login";
static TOKEN: Lazy<Mutex<Option<String>>> = Lazy::new(|| Mutex::new(None));

pub async fn get_token(client: &Client, api_key: &str) -> Result<String, TvdbError> {
    {
        let lock = TOKEN.lock().await;
        if let Some(token) = &*lock {
            println!("[TVDB][auth] token cache hit len={}", token.len());
            return Ok(token.clone());
        }
    }

    let prefix: String = api_key.chars().take(4).collect();
    println!(
        "[TVDB][auth] requesting token api_key_prefix={}*** api_key_len={}",
        prefix,
        api_key.len()
    );

    let raw = client
        .post(AUTH_URL)
        .json(&json!({ "apikey": api_key }))
        .send()
        .await?;
    let status = raw.status();
    println!("[TVDB][auth] login status={}", status);
    let response: Value = raw.json().await?;

    let token = response["data"]["token"]
        .as_str()
        .ok_or_else(|| {
            eprintln!("[TVDB][auth] missing token response={}", response);
            TvdbError::Auth("missing token in response".into())
        })?
        .to_string();

    {
        let mut lock = TOKEN.lock().await;
        *lock = Some(token.clone());
    }

    Ok(token)
}

pub async fn invalidate_token() {
    println!("[TVDB][auth] invalidating cached token");
    let mut lock = TOKEN.lock().await;
    *lock = None;
}