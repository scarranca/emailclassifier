import pg from 'pg';
export function createPool(connectionString, {local = false} = {}) {
  const url = new URL(connectionString);
  if (local && !['127.0.0.1', 'localhost'].includes(url.hostname)) throw new Error('Local DB must be loopback');
  // URL sslmode options can override pg's explicit TLS verification; prohibit them.
  for (const k of ['sslmode', 'sslcert', 'sslkey', 'sslrootcert']) {
    if (url.searchParams.has(k)) throw new Error('Configure verified TLS through the pool, not URL parameters');
  }
  return new pg.Pool({connectionString, ssl: local ? false : {rejectUnauthorized: true},
    max: 2, idleTimeoutMillis: 10000, connectionTimeoutMillis: 5000,
    idle_in_transaction_session_timeout: 10000, statement_timeout: 5000, query_timeout: 6000, application_name: 'cove-sync-api'});
}
export async function transaction(pool, owner, work) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT set_config('cove.owner_sub', $1, true)", [owner]);
    await client.query("SET LOCAL lock_timeout = '3s'");
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally { client.release(); }
}
export async function assertRuntimeRole(pool) {
  const {rows} = await pool.query(`SELECT r.rolsuper, r.rolbypassrls,
    pg_has_role(current_user, 'cove_sync_runtime', 'MEMBER') AS member,
    EXISTS(SELECT 1 FROM pg_tables WHERE schemaname='cove_sync' AND tableowner=current_user) AS owns
    FROM pg_roles r WHERE rolname=current_user`);
  if (!rows[0]?.member || rows[0].rolsuper || rows[0].rolbypassrls || rows[0].owns)
    throw new Error('API requires a non-owner, non-bypass runtime role');
}
