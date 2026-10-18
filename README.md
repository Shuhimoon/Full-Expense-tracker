# Full Expense Tracker (Full 記帳)

A self-hosted personal finance tracker delivered as a Progressive Web App.
PostgreSQL is the single source of truth, the backend is written in Go, and the
frontend is a React + Vite PWA. Base currency is TWD, time zone is Asia/Taipei,
and investment cost basis uses the moving-average method.

## Features

- **Multiple books (ledgers)** – keep separate ledgers per user and switch between them.
- **Accounts, categories and transactions** – record income, expenses and transfers per book.
- **Investment positions** – Taiwan stocks, US stocks, crypto and FX, with moving-average cost.
- **Charts** – analytics views powered by Recharts.
- **Calendar** – browse entries day by day after an opening-balance snapshot.
- **Installable PWA** – works on mobile home screens, with pull-to-refresh.

## Tech stack

| Layer    | Technology                                            |
|----------|-------------------------------------------------------|
| Backend  | Go, chi router, pgx, golang-migrate                   |
| Database | PostgreSQL 16                                         |
| Frontend | React, TypeScript, Vite, vite-plugin-pwa, Recharts    |
| Serving  | nginx (static files + reverse proxy for `/api`)       |

## Project layout

```
api/         Go API (cmd/server, internal/app, internal/auth, migrations/)
web/         React + Vite PWA
nginx.conf   nginx config used by the web image
docker-compose.yml
```

## Installation (Docker Compose)

Requirements: Docker with the Compose plugin, Node.js 20+ (to build the frontend).

1. Build the frontend (the web image copies `web/dist`):

   ```bash
   cd web
   npm ci
   npm run build
   cd ..
   ```

2. Start everything:

   ```bash
   docker compose up --build -d
   ```

3. Open:

   - Web app: http://localhost/
   - API health (via nginx): http://localhost/api/health
   - API direct (debug): http://localhost:8080/api/health
   - PostgreSQL: localhost:5432

Stop with `docker compose down`. The API runs database migrations on startup,
then listens on `:8080`.

## Configuration

The API reads these environment variables:

| Variable          | Default                                                                  | Description |
|-------------------|--------------------------------------------------------------------------|-------------|
| `DATABASE_URL`    | `postgres://fulljizhang:fulljizhang@127.0.0.1:5432/fulljizhang?sslmode=disable` | PostgreSQL connection string |
| `LISTEN_ADDR`     | `:8080`                                                                  | HTTP listen address |
| `MIGRATIONS_PATH` | first existing of `/migrations`, `migrations`, `../migrations`           | Directory of SQL migrations |

`docker-compose.yml` also sets `COOKIE_SECURE: "false"` on the api service.

### Development database credentials (hardcoded – do NOT use in production)

```
POSTGRES_DB=fulljizhang
POSTGRES_USER=fulljizhang
POSTGRES_PASSWORD=fulljizhang
```

Change these (and `DATABASE_URL`) before exposing the app anywhere.

### Networking note

The compose file uses `extra_hosts: host-gateway` so `postgres` / `api` resolve
to the published ports 5432 / 8080 on the host (a workaround for environments
where container-to-container bridge networking times out). On a normal Linux
Docker setup the same file still works.

## Usage

1. Open http://localhost/ and create an account / sign in.
2. Create or pick a book from the book bar.
3. Set the opening snapshot (accounts and balances) to lock the opening date.
4. Add accounts and categories, then record transactions.
5. Add stock / crypto trades on the Invest page; positions show moving-average cost.
6. Check the Analytics page for charts and the calendar for daily entries.

Quick API check:

```bash
curl http://localhost:8080/api/health
```

## Running tests

Backend tests live under `api/internal/...`:

```bash
cd api
go test ./...
```

Some tests in `internal/app` need PostgreSQL via `DATABASE_URL`; they are skipped
automatically if the database is unreachable:

```bash
docker compose up -d postgres
cd api
DATABASE_URL=postgres://fulljizhang:fulljizhang@localhost:5432/fulljizhang?sslmode=disable go test ./...
```

## License

Released under the [MIT License](LICENSE). Copyright (c) 2026 Shuhimoon.

---

## 中文說明

Full 記帳是自架的個人記帳 PWA：正本在 PostgreSQL，後端 Go/chi/pgx，前端 React + Vite PWA；
基準幣 TWD、時區 Asia/Taipei、投資成本採移動平均法。支援多本帳本、帳戶／分類／交易、
台股／美股／加密貨幣持倉、圖表與日曆。先在 `web/` 執行 `npm run build`，再 `docker compose up --build -d`
即可啟動。範例中的資料庫帳密為開發用寫死值，勿用於正式環境。
