import { invoke } from '@tauri-apps/api/core'

let terminalLoggingAvailable = true

export function logToTerminal(message: string, level: 'info' | 'warn' | 'error' = 'info') {
    if (!terminalLoggingAvailable) return

    void invoke('frontend_log', { level, message }).catch(() => {
        terminalLoggingAvailable = false
    })
}