import { createPool, assertRuntimeRole } from './database.js';
import { googleVerifier } from './auth.js';
import { cloudProviders } from './cloud.js';
import { createAPI } from './api.js';
const required = name => { if (!process.env[name]) throw new Error(`Missing ${name}`); return process.env[name]; };
const pool = createPool(required('DATABASE_URL'));
await assertRuntimeRole(pool);
const providers = cloudProviders({kmsKey: required('CONTENT_KMS_KEY'), bucketName: required('BODY_BUCKET')});
const app = createAPI({pool, ...providers, verifyIdentity: googleVerifier({
  audiences: required('GOOGLE_CLIENT_IDS').split(','), pilotEmails: required('PILOT_EMAILS').split(',')})});
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, async () => { await app.close(); await pool.end(); process.exit(0); });
await app.listen({host:'0.0.0.0', port:Number(process.env.PORT ?? 8080)});
