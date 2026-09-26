import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { createAPI } from '../src/api.js';
import { createPool, transaction, assertRuntimeRole } from '../src/database.js';
import { newKey, seal, open } from '../src/crypto.js';
import { googleVerifier } from '../src/auth.js';

// Dedicated loopback-only synthetic database. Never point these tests at PlanetScale.
const admin = new pg.Pool({connectionString:'postgres://postgres:cove-synthetic-test@127.0.0.1:55439/postgres'});
let pool;
let app;
let clock = new Date('2026-09-25T12:00:00Z');
const objects = new Map();
const master = newKey();
let uploadHook;
const keys = {
  async wrap(k, a) { return seal(master, k.toString('base64'), a); },
  async unwrap(k, a) { return Buffer.from(open(master, k, a), 'base64'); }
};
before(async () => {
  await admin.query('DROP SCHEMA IF EXISTS cove_sync CASCADE');
  await admin.query('DROP ROLE IF EXISTS cove_test_api');
  await admin.query('DROP ROLE IF EXISTS cove_sync_runtime');
  await admin.query(await readFile(new URL('../migrations/001_sync.sql', import.meta.url),'utf8'));
  await admin.query("CREATE ROLE cove_test_api LOGIN PASSWORD 'synthetic-api-only' NOSUPERUSER NOBYPASSRLS; GRANT cove_sync_runtime TO cove_test_api");
  pool = createPool('postgres://cove_test_api:synthetic-api-only@127.0.0.1:55439/postgres',{local:true});
  await assertRuntimeRole(pool);
  app = createAPI({pool, keys, now:() => clock,
    verifyIdentity:async token => { if(!token.startsWith('fixture-')) throw new Error('no'); return {sub:token}; },
    bodies:{ async put(k,v) { if(uploadHook) await uploadHook(); objects.set(k,v); },
      async get(k) { if(!objects.has(k)) throw new Error('missing'); return objects.get(k); } }});
});
after(async () => { await app?.close(); await pool?.end(); await admin.end(); });
const request = (owner, method, url, payload) => app.inject({method,url,payload,headers:{authorization:`Bearer ${owner}`}});
const connect = async owner => {
  const r=await request(owner,'POST','/v1/connection',{consentVersion:'cloud-mail-v1'});
  assert.equal(r.statusCode,200,r.body); return r.json();
};
const mail = (id='abc') => ({id,threadID:'thread',receivedAt:clock.toISOString(),labels:['INBOX','UNREAD'],
  metadata:{sender:'Private Sender',senderEmail:'sender@example.com',to:'receiver@example.com',subject:'Private subject',messageID:'<private@example.com>'},
  body:{text:'Private body text',html:'<p>Private body text</p>',truncated:false}});
const input = (a, messages=[mail()], deletedIDs=[]) => ({...{accountID:a.accountID,baseRevision:a.revision},requestID:randomUUID(),messages,deletedIDs});

test('authentication, explicit consent, strict payloads and body limit',async () => {
  assert.equal((await app.inject('/v1/connection')).statusCode,401);
  assert.equal((await request('bad','GET','/v1/connection')).statusCode,401);
  assert.equal((await request('fixture-auth','POST','/v1/connection',{})).statusCode,400);
  const a=await connect('fixture-auth');
  assert.equal((await request('fixture-auth','POST','/v1/messages/batch',{...input(a),owner_sub:'fixture-victim'})).statusCode,400);
  const oversized=input(a);oversized.messages[0].body.text='x'.repeat(1100000);
  assert.equal((await request('fixture-auth','POST','/v1/messages/batch',oversized)).statusCode,413);
});
test('encrypted round trip, tenant isolation and RLS on pooled connections',async () => {
  const a=await connect('fixture-alice'); const b=await connect('fixture-bob');
  const r=await request('fixture-alice','POST','/v1/messages/batch',input(a));assert.equal(r.statusCode,200,r.body);
  const raw=(await admin.query("SELECT * FROM cove_sync.messages WHERE owner_sub='fixture-alice'")).rows[0];
  assert.equal(raw.content_cipher.includes(Buffer.from('Private')),false);
  assert.equal(objects.get(raw.body_object).includes(Buffer.from('Private')),false);
  const feed=await request('fixture-alice','GET',`/v1/messages/changes?accountID=${a.accountID}&after=0`);
  assert.equal(feed.json().messages[0].metadata.subject,'Private subject');
  const body=await request('fixture-alice','GET',`/v1/messages/abc/body?accountID=${a.accountID}`);
  assert.equal(body.json().text,'Private body text');
  assert.equal((await request('fixture-bob','GET',`/v1/messages/abc/body?accountID=${b.accountID}`)).statusCode,404);
  assert.equal((await request('fixture-bob','GET',`/v1/messages/changes?accountID=${a.accountID}`)).statusCode,409);
  await transaction(pool,'fixture-bob',async c => assert.equal((await c.query('SELECT * FROM cove_sync.messages')).rowCount,0));
  assert.equal((await pool.query('SELECT * FROM cove_sync.messages')).rowCount,0,'transaction-local identity must not leak through pool');
  await assert.rejects(transaction(pool,'fixture-bob',c => c.query("INSERT INTO cove_sync.accounts(owner_sub,account_id,wrapped_key) VALUES('fixture-impostor',$1,$2)",[randomUUID(),Buffer.from('x')])));
  await assert.rejects(assertRuntimeRole(admin));
});
test('idempotent retries, body reuse, stale writes and conflicting request IDs',async () => {
  const a=await connect('fixture-retry');const batch=input(a);const before=objects.size;
  const first=await request('fixture-retry','POST','/v1/messages/batch',batch); assert.equal(first.statusCode,200,first.body);
  const retry=await request('fixture-retry','POST','/v1/messages/batch',batch); assert.deepEqual(retry.json(),first.json());assert.equal(objects.size,before+1);
  assert.equal((await request('fixture-retry','POST','/v1/messages/batch',{...batch,messages:[{...mail(),labels:[]}]})).statusCode,409);
  assert.equal((await request('fixture-retry','POST','/v1/messages/batch',input(a,[mail('other')]))).statusCode,409);
  const changed=input({...a,...first.json()},[{...mail(),labels:['INBOX']}]);
  const result=await request('fixture-retry','POST','/v1/messages/batch',changed);assert.equal(result.statusCode,200,result.body);
  assert.equal(objects.size,before+1,'changing labels does not duplicate the body object');
});
test('concurrent batches serialize: one wins, stale one cannot overwrite',async () => {
  const a=await connect('fixture-concurrent');
  const r=await Promise.all([request('fixture-concurrent','POST','/v1/messages/batch',input(a,[mail('one')])),request('fixture-concurrent','POST','/v1/messages/batch',input(a,[mail('two')]))]);
  assert.deepEqual(r.map(x=>x.statusCode).sort(),[200,409]);
  const rows=await transaction(pool,'fixture-concurrent',c=>c.query('SELECT revision FROM cove_sync.messages'));
  assert.equal(rows.rowCount,1);assert.equal(rows.rows[0].revision,'1');
});
test('unique revisions paginate without losing changes and deletions yield tombstones',async () => {
  let a=await connect('fixture-pagination');
  for(let n=0;n<101;n+=5){
    const r=await request('fixture-pagination','POST','/v1/messages/batch',input(a,Array.from({length:Math.min(5,101-n)},(_,i)=>mail(`id${n+i}`))));
    assert.equal(r.statusCode,200,r.body);a={...a,...r.json()};
  }
  const first=(await request('fixture-pagination','GET',`/v1/messages/changes?accountID=${a.accountID}&after=0`)).json();
  assert.equal(first.messages.length,100);assert.equal(first.hasMore,true);assert.equal(first.cursor,'100');
  const next=(await request('fixture-pagination','GET',`/v1/messages/changes?accountID=${a.accountID}&after=${first.cursor}`)).json();
  assert.equal(next.messages.length,1);assert.equal(next.messages[0].id,'id100');
  const removed=await request('fixture-pagination','POST','/v1/messages/batch',input(a,[],['id100']));assert.equal(removed.statusCode,200,removed.body);
  const tombstones=(await request('fixture-pagination','GET',`/v1/messages/changes?accountID=${a.accountID}&after=101`)).json();
  assert.deepEqual(tombstones.messages,[{id:'id100',revision:'102',deleted:true}]);
  assert.equal((await request('fixture-pagination','GET',`/v1/messages/id100/body?accountID=${a.accountID}`)).statusCode,404);
});
test('deleted account cannot be recreated by an in-flight upload',async () => {
  const a=await connect('fixture-delete');let resume;let arrived;
  const gate=new Promise(r=>{arrived=r});
  uploadHook=async()=>{arrived();await new Promise(r=>{resume=r})};
  const pending=request('fixture-delete','POST','/v1/messages/batch',input(a));await gate;
  assert.equal((await request('fixture-delete','DELETE','/v1/connection',{accountID:a.accountID})).statusCode,200);
  resume();uploadHook=undefined;assert.equal((await pending).statusCode,409);
  assert.equal((await request('fixture-delete','GET','/v1/connection')).statusCode,404);
  const replacement=await connect('fixture-delete');assert.notEqual(replacement.accountID,a.accountID);
  assert.equal((await request('fixture-delete','POST','/v1/messages/batch',input(a))).statusCode,409);
});
test('body expires independently of object cleanup; rejects old initial uploads',async () => {
  const a=await connect('fixture-expiry');const batch=input(a);
  assert.equal((await request('fixture-expiry','POST','/v1/messages/batch',batch)).statusCode,200);
  clock=new Date(clock.getTime()+31*86400000);
  assert.equal((await request('fixture-expiry','GET',`/v1/messages/abc/body?accountID=${a.accountID}`)).statusCode,404);
  const feed=(await request('fixture-expiry','GET',`/v1/messages/changes?accountID=${a.accountID}`)).json();assert.equal(feed.messages[0].bodyAvailable,false);
  const b=await connect('fixture-old');assert.equal((await request('fixture-old','POST','/v1/messages/batch',input(b,batch.messages))).statusCode,400);
});
test('AEAD rejects moved and modified ciphertext',()=>{
  const key=newKey(), cipher=seal(key,{private:'message'},'account/message');
  assert.throws(()=>open(key,cipher,'another/message'));
  const tampered=Buffer.from(cipher);tampered[14]^=1;assert.throws(()=>open(key,tampered,'account/message'));
});
test('identity verifier requires approved audiences, verified email and pilot membership',async()=>{
  let payload={sub:'123',email:'pilot@example.com',email_verified:true,hd:'example.com',azp:'desktop'};
  const verify=googleVerifier({audiences:['desktop'],pilotEmails:['pilot@example.com']},{async verifyIdToken(options){assert.deepEqual(options.audience,['desktop']);return {getPayload:()=>payload}}});
  assert.deepEqual(await verify('token'),{sub:'123'});
  for(const patch of [{email_verified:false},{email:'someone@example.com'},{azp:'attacker'},{hd:undefined}]){
    const original=payload;payload={...payload,...patch};await assert.rejects(verify('token'));payload=original;
  }
});


test('Swift uppercase UUID encoding is normalized for uploads, reads and removal',async () => {
  const owner='fixture-swift-uuid'; const a=await connect(owner);
  const payload=input(a); payload.accountID=payload.accountID.toUpperCase(); payload.requestID=payload.requestID.toUpperCase();
  const r=await request(owner,'POST','/v1/messages/batch',payload); assert.equal(r.statusCode,200,r.body);
  const lower={...payload,accountID:payload.accountID.toLowerCase(),requestID:payload.requestID.toLowerCase()};
  assert.equal((await request(owner,'POST','/v1/messages/batch',lower)).json().revision,r.json().revision);
  assert.equal((await request(owner,'GET',`/v1/messages/changes?accountID=${payload.accountID}`)).json().messages.length,1);
  assert.equal((await request(owner,'GET',`/v1/messages/abc/body?accountID=${payload.accountID}`)).statusCode,200);
  assert.equal((await request(owner,'DELETE','/v1/connection',{accountID:payload.accountID})).statusCode,200);
});
