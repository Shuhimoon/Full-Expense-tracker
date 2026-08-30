# Full 記帳 v1

個人記帳 PWA。正本在 PostgreSQL，後端 Go/chi/pgx，前端 React + Vite PWA。
基準幣 TWD、時區 Asia/Taipei、成本法移動平均。

## 怎麼跑

前端靜態檔需已建置在 `web/dist`（此目錄若已有 dist 可略過建置）。然後：

```bash
cd /workspace/full-jizhang
docker compose up --build -d
```

獨立 CLI：`docker-compose up --build -d`

開：

- 網頁（nginx 反代 `/api`）：http://localhost/
- API health：http://localhost/api/health
- API 直連（除錯）：http://localhost:8080/api/health
- Postgres：localhost:5432

停止：`docker compose down`

### 開發用資料庫帳密（寫死，勿用於正式環境）

- POSTGRES_DB=fulljizhang
- POSTGRES_USER=fulljizhang
- POSTGRES_PASSWORD=fulljizhang

### 本機組網路備註

此環境 Docker bridge 容器互連會 timeout，compose 以 `extra_hosts: host-gateway`
把 `postgres` / `api` 指到已發布的 5432 / 8080。一般 Linux Docker 若 bridge 正常，
同一份 compose 仍可透過發布埠運作。

### 前端建置（若沒有 web/dist）

在 Node 20+ 環境進入 `web/`，安裝依賴並執行 `run build`（Vite PWA）。

API 映像會在啟動時跑 golang-migrate，再聽 :8080。
