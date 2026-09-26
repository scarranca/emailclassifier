// One-shot deployment smoke check. Only generated synthetic content is used.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createPool, assertRuntimeRole } from './database.js';
import { cloudProviders } from './cloud.js';
import { newKey, seal, open, context } from './crypto.js';
const pool = createPool(process.env.DATABASE_URL);
try {
  await assertRuntimeRole(pool);
  const {keys,bodies} = cloudProviders({kmsKey:process.env.CONTENT_KMS_KEY,bucketName:process.env.BODY_BUCKET});
  const account = randomUUID(); const owner = 'deployment-check-' + account;
  const key = newKey(); const wrapped = await keys.wrap(key,account);
  assert.deepEqual(await keys.unwrap(wrapped,account),key);
  await assert.rejects(keys.unwrap(wrapped,randomUUID()));
  const name = `${account}/${randomUUID()}`;
  const fixture = {text:'Synthetic Cove deployment check'};
  await bodies.put(name,seal(key,fixture,context(account,'fixture','body')));
  assert.deepEqual(open(key,await bodies.get(name),context(account,'fixture','body')),fixture);
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    await c.query("SELECT set_config('cove.owner_sub',$1,true)",[owner]);
    await c.query('INSERT INTO cove_sync.accounts(owner_sub,account_id,wrapped_key) VALUES($1,$2,$3)',[owner,account,wrapped]);
    assert.equal((await c.query('SELECT account_id FROM cove_sync.accounts')).rowCount,1);
    await c.query("SELECT set_config('cove.owner_sub',$1,true)",[owner+'-other']);
    assert.equal((await c.query('SELECT account_id FROM cove_sync.accounts')).rowCount,0);
  } finally { await c.query('ROLLBACK');c.release(); }
  console.log('PASS: verified TLS, restricted role, tenant isolation, KMS authenticated wrapping and encrypted object round trip. Synthetic DB transaction rolled back; small ciphertext object expires by lifecycle.');
} catch(e) { console.error('Deployment storage check failed:',e.code ?? e.name);process.exitCode=1; }
finally { await pool.end(); }
