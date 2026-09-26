import { readFile } from 'node:fs/promises';
import { createPool } from './database.js';
// Explicit one-shot first migration: never auto-run DDL when the API starts.
const pool = createPool(process.env.MIGRATION_DATABASE_URL);
try {
  await pool.query(await readFile(new URL('../migrations/001_sync.sql', import.meta.url), 'utf8'));
  console.log('Cove sync migration applied. Grant the API login membership in cove_sync_runtime separately.');
} finally { await pool.end(); }
