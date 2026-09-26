-- Reviewed deployment migration. Run only as the migration role, never the API role.
BEGIN;
CREATE ROLE cove_sync_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE SCHEMA cove_sync;
REVOKE ALL ON SCHEMA cove_sync FROM PUBLIC;
GRANT USAGE ON SCHEMA cove_sync TO cove_sync_runtime;
CREATE TABLE cove_sync.accounts (
  owner_sub text PRIMARY KEY,
  account_id uuid NOT NULL UNIQUE,
  wrapped_key bytea NOT NULL,
  revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE cove_sync.messages (
  owner_sub text NOT NULL REFERENCES cove_sync.accounts(owner_sub) ON DELETE CASCADE,
  message_id text NOT NULL,
  thread_id text NOT NULL,
  received_at timestamptz NOT NULL,
  labels text[] NOT NULL,
  revision bigint NOT NULL CHECK (revision > 0),
  deleted boolean NOT NULL DEFAULT false,
  content_cipher bytea,
  content_hash text,
  body_object text,
  body_hash text,
  body_expires_at timestamptz,
  PRIMARY KEY (owner_sub, message_id),
  CHECK (NOT deleted OR (content_cipher IS NULL AND body_object IS NULL))
);
CREATE INDEX messages_revision ON cove_sync.messages(owner_sub, revision, message_id);
CREATE INDEX messages_received ON cove_sync.messages(owner_sub, received_at DESC) WHERE NOT deleted;
CREATE TABLE cove_sync.receipts (
  owner_sub text NOT NULL REFERENCES cove_sync.accounts(owner_sub) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  request_hash text NOT NULL,
  revision bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(owner_sub, request_id)
);
ALTER TABLE cove_sync.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cove_sync.accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE cove_sync.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE cove_sync.messages FORCE ROW LEVEL SECURITY;
ALTER TABLE cove_sync.receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cove_sync.receipts FORCE ROW LEVEL SECURITY;
CREATE POLICY account_owner ON cove_sync.accounts TO cove_sync_runtime
  USING (owner_sub = current_setting('cove.owner_sub', true))
  WITH CHECK (owner_sub = current_setting('cove.owner_sub', true));
CREATE POLICY message_owner ON cove_sync.messages TO cove_sync_runtime
  USING (owner_sub = current_setting('cove.owner_sub', true))
  WITH CHECK (owner_sub = current_setting('cove.owner_sub', true));
CREATE POLICY receipt_owner ON cove_sync.receipts TO cove_sync_runtime
  USING (owner_sub = current_setting('cove.owner_sub', true))
  WITH CHECK (owner_sub = current_setting('cove.owner_sub', true));
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA cove_sync TO cove_sync_runtime;
COMMIT;
