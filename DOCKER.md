# Docker Quickstart

## 1) Prepare runtime config

Create your host config so it is mounted into the container:

```bash
mkdir -p ~/.clawmacs
cp projects/clambda-core/example-init.lisp ~/.clawmacs/init.lisp
```

Make sure your `~/.clawmacs/init.lisp` defines your agents and does not hardcode secrets.

## 2) Set API token

Edit `docker-compose.yml` and change:

- `CLAWMACS_API_TOKEN`

## 3) Build and run

```bash
docker compose up -d --build
```

## 4) Verify

```bash
curl http://127.0.0.1:18789/health
curl -H "Authorization: Bearer <your-token>" http://127.0.0.1:18789/api/system
```

## 5) Codex OAuth link flow

The OAuth store is persisted in Docker volume `clawmacs-home` at:

`/root/.clawmacs/auth/codex-oauth.json`

You can complete OAuth via your configured channel flow (`/codex_login`, `/codex_link`, `/codex_status`).
