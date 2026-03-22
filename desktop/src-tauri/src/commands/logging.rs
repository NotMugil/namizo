#[tauri::command]
pub fn frontend_log(level: String, message: String) {
    eprintln!("[frontend:{}] {}", level, message);
}