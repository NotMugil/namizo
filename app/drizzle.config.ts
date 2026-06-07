import { defineConfig } from 'drizzle-kit';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

// Auto-load vars from desktop/.env (the single combined env file)
const __dirname = dirname(fileURLToPath(import.meta.url));
try {
  const envFile = readFileSync(resolve(__dirname, '.env'), 'utf-8');
  for (const line of envFile.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx === -1) continue;
    const key = trimmed.slice(0, idx).trim();
    const raw = trimmed.slice(idx + 1).trim();
    const value = raw.replace(/^["']|["']$/g, '');
    if (!process.env[key]) process.env[key] = value;
  }
} catch { /* env file missing — DATABASE_URL must be set externally */ }

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is not set. Add it to desktop/.env');
}

export default defineConfig({
  schema: './src/lib/server/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL,
  },
});
