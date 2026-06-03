// Keep pages client-side rendered so Tauri invoke() calls work correctly.
// Auth guards in +layout.server.ts still run on the server and can redirect.
export const ssr = false;
