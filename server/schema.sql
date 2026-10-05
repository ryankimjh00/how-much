CREATE TABLE IF NOT EXISTS accounts (
    id uuid PRIMARY KEY,
    recovery_hash text UNIQUE NOT NULL,
    rows jsonb NOT NULL DEFAULT '[]',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sessions (
    token_hash text PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_account ON sessions(account_id);
CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires_at);
CREATE TABLE IF NOT EXISTS shared_prices (
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    row_id text NOT NULL,
    product_key text NOT NULL,
    record jsonb NOT NULL,
    PRIMARY KEY (account_id, row_id)
);
CREATE INDEX IF NOT EXISTS shared_prices_product ON shared_prices(product_key);
