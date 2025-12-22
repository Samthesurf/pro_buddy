# Deploying the backend on Oracle Cloud (Always Free)

This deploy uses an Oracle Always Free Ubuntu VM + Docker Compose, and puts HTTPS in front using Caddy.

## 0) Create the Always Free VM
- Create an OCI account, then create a **Compute Instance** in your **Home Region**.
- Pick Ubuntu (22.04/24.04) and an **Always Free** shape (Ampere A1 is usually the best choice if available).
- Give it a public IPv4 and keep SSH keys safe.

Tip: on Ubuntu images the default SSH user is usually `ubuntu` (Oracle Linux uses `opc`).

## 1) Open the right inbound ports (OCI + VM)
In OCI (VCN security list / NSG), allow inbound TCP:
- **22** (SSH) — ideally only from your IP
- **80** (HTTP) — required for Let’s Encrypt
- **443** (HTTPS)

On the VM, if you use `ufw`:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## 2) Install Docker on the VM

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Log out/in (or reconnect SSH) so the `docker` group applies.

## 3) Copy the backend onto the VM
### Option A (recommended): `git clone`
```bash
sudo mkdir -p /opt/pro-buddy && sudo chown "$USER":"$USER" /opt/pro-buddy
cd /opt/pro-buddy
git clone <YOUR_REPO_URL> .
cd backend
```

### Option B: `rsync` from your laptop (avoids copying your local venv)
From your laptop (from the repo root):

```bash
rsync -av \
  --exclude 'pro_buddy' \
  --exclude '__pycache__' \
  --exclude 'chroma_data' \
  ./backend/ \
  <SSH_USER>@<VM_PUBLIC_IP>:/opt/pro-buddy/backend/
```

Then on the VM:

```bash
cd /opt/pro-buddy/backend
```

## 4) Add secrets/config on the VM
Create `.env`:

```bash
cp env.example .env
nano .env
```

At minimum, set:
- `DEBUG=false`
- `GEMINI_API_KEY=...`
- `CLOUDFLARE_ACCOUNT_ID=...`
- `CLOUDFLARE_API_TOKEN=...`

Add Firebase Admin credentials:
- Download a **service account JSON** in Firebase Console → Project Settings → Service accounts.
- Copy it to the VM as `backend/firebase-credentials.json`
- In Docker, it’s mounted at `/app/firebase-credentials.json` automatically by `docker-compose.yml`.

## 4.5) (Optional) Persist usage history + cooldowns in Cloudflare D1 (via Worker)
By default, the backend keeps usage history in memory (lost on restart). If you want persistence **and** lower RAM growth, deploy the included Worker:
- Worker project: `backend/cloudflare/usage-store-worker/`
- Follow its README to create D1, apply migrations, set `WORKER_TOKEN`, and deploy.

Then set these in `backend/.env` on the VM:
- `USAGE_STORE_WORKER_URL=https://<your-worker>.<your-subdomain>.workers.dev`
- `USAGE_STORE_WORKER_TOKEN=<same value as WORKER_TOKEN>`

## 5) Start the backend

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f api
```

Sanity check (on the VM):

```bash
curl -s http://127.0.0.1:8000/health
```

## 6) Add HTTPS with a free domain (DuckDNS) + Caddy
You need a domain for HTTPS. A simple free option is DuckDNS.

1) Create a DuckDNS subdomain and point it to your VM’s public IP (A record).
2) Install Caddy:

```bash
sudo apt update && sudo apt install -y caddy
```

3) Create `/etc/caddy/Caddyfile`:

```caddyfile
your-subdomain.duckdns.org {
  reverse_proxy 127.0.0.1:8000
}
```

4) Reload Caddy:

```bash
sudo systemctl enable --now caddy
sudo systemctl reload caddy
```

Now your API base becomes:
- `https://your-subdomain.duckdns.org/api/v1`

## 7) Point Flutter (mobile) to the new URL
Update your backend base URL (where you currently use `http://10.0.2.2:8000/api/v1`) to:
- `https://your-subdomain.duckdns.org/api/v1`

No CORS configuration is needed for Flutter mobile.
