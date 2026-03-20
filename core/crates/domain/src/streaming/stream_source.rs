use std::collections::HashMap;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StreamSource {
    pub url: String,
    pub quality: String,
    pub kind: String,
    pub headers: Option<HashMap<String, String>>,
}