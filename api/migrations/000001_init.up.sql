CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE account_type AS ENUM ('cash', 'bank', 'credit_card', 'broker', 'exchange');
CREATE TYPE category_kind AS ENUM ('income', 'expense');
CREATE TYPE entry_type AS ENUM ('expense', 'income', 'transfer', 'opening_balance');
CREATE TYPE asset_class AS ENUM ('tw_stock', 'us_stock', 'crypto', 'fx');
CREATE TYPE ccy AS ENUM ('TWD', 'USD');
CREATE TYPE trade_side AS ENUM ('buy', 'sell', 'transfer_in', 'transfer_out', 'opening', 'airdrop');
CREATE TYPE quote_source AS ENUM ('auto', 'manual');

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email citext NOT NULL UNIQUE,
    password_hash text NOT NULL,
    last_book_id uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sessions_user_id ON sessions (user_id);
CREATE INDEX sessions_expires_at ON sessions (expires_at);

CREATE TABLE books (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name text NOT NULL,
    archived_at timestamptz,
    base_currency text NOT NULL DEFAULT 'TWD' CHECK (base_currency = 'TWD'),
    opening_date date,
    opening_locked boolean NOT NULL DEFAULT false,
    timezone text NOT NULL DEFAULT 'Asia/Taipei' CHECK (timezone = 'Asia/Taipei'),
    cost_method text NOT NULL DEFAULT 'avg' CHECK (cost_method = 'avg'),
    version int NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX books_user_name_active ON books (user_id, name) WHERE archived_at IS NULL;
CREATE INDEX books_user_id ON books (user_id);

ALTER TABLE users
    ADD CONSTRAINT users_last_book_fk
    FOREIGN KEY (last_book_id) REFERENCES books(id) ON DELETE SET NULL;

CREATE TABLE accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    name text NOT NULL,
    type account_type NOT NULL,
    archived_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    version int NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX accounts_book_name_active ON accounts (book_id, name) WHERE archived_at IS NULL;
CREATE INDEX accounts_book_id ON accounts (book_id);

CREATE TABLE categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    name text NOT NULL,
    kind category_kind NOT NULL,
    is_system boolean NOT NULL DEFAULT false,
    archived_at timestamptz,
    sort int NOT NULL DEFAULT 0,
    version int NOT NULL DEFAULT 1
);
CREATE INDEX categories_book_id ON categories (book_id);

CREATE TABLE instruments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    symbol text NOT NULL,
    name text NOT NULL DEFAULT '',
    asset_class asset_class NOT NULL,
    quote_currency ccy NOT NULL,
    UNIQUE (book_id, asset_class, symbol)
);

CREATE TABLE entries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    date date NOT NULL,
    type entry_type NOT NULL,
    amount bigint NOT NULL CHECK (amount > 0),
    account_id uuid NOT NULL REFERENCES accounts(id),
    to_account_id uuid REFERENCES accounts(id),
    category_id uuid REFERENCES categories(id),
    note text NOT NULL DEFAULT '',
    instrument_id uuid REFERENCES instruments(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    version int NOT NULL DEFAULT 1
);
CREATE INDEX entries_book_date ON entries (book_id, date) WHERE deleted_at IS NULL;
CREATE INDEX entries_account ON entries (account_id) WHERE deleted_at IS NULL;

CREATE TABLE positions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id),
    instrument_id uuid NOT NULL REFERENCES instruments(id),
    qty numeric(20,8) NOT NULL DEFAULT 0 CHECK (qty >= 0),
    cost_twd numeric(28,10) NOT NULL DEFAULT 0 CHECK (cost_twd >= 0),
    realized_twd bigint NOT NULL DEFAULT 0,
    cost_unknown boolean NOT NULL DEFAULT false,
    version int NOT NULL DEFAULT 1,
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (account_id, instrument_id)
);

CREATE TABLE trades (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    date date NOT NULL,
    account_id uuid NOT NULL REFERENCES accounts(id),
    instrument_id uuid NOT NULL REFERENCES instruments(id),
    side trade_side NOT NULL,
    qty numeric(20,8) NOT NULL CHECK (qty > 0),
    price numeric(20,8),
    price_ccy ccy,
    fee_twd bigint NOT NULL DEFAULT 0 CHECK (fee_twd >= 0),
    proceeds_or_cost_twd bigint NOT NULL DEFAULT 0,
    fx_usd_twd numeric(20,8) NOT NULL DEFAULT 1,
    realized_twd bigint,
    pair_id uuid REFERENCES trades(id),
    note text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    version int NOT NULL DEFAULT 1
);
CREATE INDEX trades_book_date ON trades (book_id, date) WHERE deleted_at IS NULL;
CREATE INDEX trades_position ON trades (account_id, instrument_id) WHERE deleted_at IS NULL;

CREATE TABLE quotes (
    instrument_id uuid PRIMARY KEY REFERENCES instruments(id) ON DELETE CASCADE,
    price numeric(20,8) NOT NULL,
    ccy ccy NOT NULL,
    as_of timestamptz NOT NULL,
    source quote_source NOT NULL DEFAULT 'auto',
    locked boolean NOT NULL DEFAULT false
);

CREATE TABLE fx_rates (
    book_id uuid PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
    usd_twd numeric(20,8) NOT NULL,
    as_of timestamptz NOT NULL,
    source text NOT NULL DEFAULT 'auto'
);

CREATE TABLE opening_cash_drafts (
    book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    amount bigint NOT NULL CHECK (amount >= 0),
    PRIMARY KEY (book_id, account_id)
);

CREATE TABLE opening_position_drafts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    instrument_id uuid REFERENCES instruments(id),
    symbol text NOT NULL,
    name text NOT NULL DEFAULT '',
    asset_class asset_class NOT NULL,
    quote_currency ccy NOT NULL,
    qty numeric(20,8) NOT NULL CHECK (qty > 0),
    cost_twd numeric(28,10) NOT NULL DEFAULT 0 CHECK (cost_twd >= 0),
    cost_unknown boolean NOT NULL DEFAULT false
);

CREATE TABLE idempotency_keys (
    key uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    method text NOT NULL,
    path text NOT NULL,
    response_status int NOT NULL,
    response_body jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idempotency_keys_created ON idempotency_keys (created_at);
