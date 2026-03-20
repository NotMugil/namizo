use regex::Regex;

pub fn unpack(args: &str) -> String {
    if args.is_empty() {
        return String::new();
    }

    let mut split_index = args.rfind(".split('|')");
    if split_index.is_none() {
        split_index = args.rfind(".split(\"|\")");
    }
    let split_index = match split_index {
        Some(v) => v,
        None => return String::new(),
    };

    if split_index == 0 {
        return String::new();
    }

    let keywords_end_quote_index = split_index - 1;
    let quote_char = args.as_bytes()[keywords_end_quote_index] as char;

    let mut keywords_start_quote_index: Option<usize> = None;
    for i in (0..keywords_end_quote_index).rev() {
        let ch = args.as_bytes()[i] as char;
        let escaped = i > 0 && args.as_bytes()[i - 1] as char == '\\';
        if ch == quote_char && !escaped {
            keywords_start_quote_index = Some(i);
            break;
        }
    }
    let keywords_start_quote_index = match keywords_start_quote_index {
        Some(v) => v,
        None => return String::new(),
    };

    let keywords_str = &args[keywords_start_quote_index + 1..keywords_end_quote_index];
    let keywords: Vec<&str> = keywords_str.split('|').collect();

    let before_keywords = args[..keywords_start_quote_index].trim();
    if !before_keywords.ends_with(',') {
        return String::new();
    }

    let comma_after_count = before_keywords.len() - 1;
    let comma_before_count = match before_keywords[..comma_after_count].rfind(',') {
        Some(v) => v,
        None => return String::new(),
    };
    let comma_before_radix = match before_keywords[..comma_before_count].rfind(',') {
        Some(v) => v,
        None => return String::new(),
    };

    let count_str = before_keywords[comma_before_count + 1..comma_after_count].trim();
    let radix_str = before_keywords[comma_before_radix + 1..comma_before_count].trim();
    let payload_raw = before_keywords[..comma_before_radix].trim();

    let mut payload = payload_raw.to_string();
    if (payload.starts_with('\'') && payload.ends_with('\''))
        || (payload.starts_with('\"') && payload.ends_with('\"'))
    {
        payload = payload[1..payload.len() - 1].to_string();
    }

    let radix = radix_str.parse::<usize>().unwrap_or(10);
    let count = count_str.parse::<usize>().unwrap_or(0);

    payload = payload
        .replace("\\'", "'")
        .replace("\\\"", "\"")
        .replace("\\\\", "\\");

    if keywords.is_empty() {
        return payload;
    }

    let mut dict = std::collections::HashMap::new();
    for i in 0..count {
        let key = to_base(i, radix);
        let value = if i < keywords.len() && !keywords[i].is_empty() {
            keywords[i].to_string()
        } else {
            key.clone()
        };
        dict.insert(key, value);
    }

    let word_re = Regex::new(r"\b\w+\b").expect("valid regex");
    word_re
        .replace_all(&payload, |caps: &regex::Captures<'_>| {
            let word = caps.get(0).map(|m| m.as_str()).unwrap_or_default();
            dict.get(word).cloned().unwrap_or_else(|| word.to_string())
        })
        .to_string()
}

fn to_base(value: usize, radix: usize) -> String {
    const CHARS: &[u8] = b"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    if value < radix {
        return (CHARS[value] as char).to_string();
    }
    format!("{}{}", to_base(value / radix, radix), CHARS[value % radix] as char)
}
