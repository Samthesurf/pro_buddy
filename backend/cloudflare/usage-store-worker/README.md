## Pro Buddy — Usage Store Worker (Cloudflare Workers + D1)

This Worker provides **persistent storage** for app usage feedback + notification cooldowns using **Cloudflare D1**.

It is designed to be called **server-to-server** from the FastAPI backend (Oracle VM), so it uses a **shared secret** header for auth.

### What it stores
- **Usage feedback events** (the records returned by `/api/v1/monitor/app-usage`)
- **Notification cooldown timestamps** (to decide whether to notify without keeping in-memory state)

---

## 1) Prereqs
- Install Wrangler: `npm i -g wrangler`
- Login: `wrangler login`

---

## 2) Create the D1 database
From this directory:

```bash
wrangler d1 create pro-buddy
```

Copy the printed **database_id** into `wrangler.toml`.

---

## 3) Apply migrations

```bash
wrangler d1 migrations apply pro-buddy
```

---

## 4) Set the Worker secret (shared token)

```bash
wrangler secret put WORKER_TOKEN
```

Use a long random string and store the same value in your backend `.env` as `USAGE_STORE_WORKER_TOKEN`.

---

## 5) Deploy

```bash
wrangler deploy
```

Wrangler will print your Worker URL. Set it in the backend `.env` as `USAGE_STORE_WORKER_URL`.

---

## 6) Backend config
In `backend/.env` (and `docker-compose.yml` env), set:
- `USAGE_STORE_WORKER_URL=https://<your-worker>.<your-subdomain>.workers.dev`
- `USAGE_STORE_WORKER_TOKEN=<the same value you set via wrangler secret>`

---

## API (internal)
All `/v1/*` endpoints require header:
- `X-ProBuddy-Worker-Token: <WORKER_TOKEN>`

### `POST /v1/cooldowns/check-and-set`
Checks cooldown and atomically sets the last-sent timestamp if allowed.

Body:
```json
{
  "user_id": "uid",
  "package_name": "com.example",
  "alignment": "aligned|neutral|misaligned",
  "cooldown_seconds": 3600
}
```

Response:
```json
{ "should_notify": true, "now_ms": 1730000000000 }
```

### `POST /v1/usage-feedback`
Upserts a usage feedback event.

### `GET /v1/usage-feedback/history`
Query params:
- `user_id` (required)
- `start_ms` / `end_ms` (optional)
- `limit` (optional, default 50, max 5000)
