<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-28 | Updated: 2026-04-28 -->

# proxy

## Purpose
Caddy-based reverse proxy Docker stack. Runs as shared gateway for local dev sites, terminating HTTPS and forwarding to named Docker containers on the `proxy` network.

## Key Files

| File | Description |
|------|-------------|
| `Caddyfile` | Caddy virtual host config — one block per local site |
| `docker-compose.yml` | Caddy service definition, volumes, and `proxy` Docker network |

## For AI Agents

### Working In This Directory
- Not a stow package — files are not symlinked to `$HOME`
- Start stack: `make proxy` (runs `docker compose up -d`)
- Add new site: add a block to `Caddyfile`, target container must be on `proxy` Docker network
- Caddy auto-provisions TLS for `.local` domains via its internal CA

### Adding a New Local Site
1. Add reverse proxy block to `Caddyfile`:
   ```
   https://mysite.local {
       reverse_proxy mysite-container:80
   }
   ```
2. Ensure target service joins `proxy` network in its own `docker-compose.yml`:
   ```yaml
   networks:
     proxy:
       external: true
   ```
3. `docker compose restart caddy` — hot-reload config

### Testing Requirements
- `docker compose config` — validate compose syntax
- `curl -k https://envisionus.local` — verify proxy routing (after stack up)

## Dependencies

### External
- `docker` / `docker compose` — container runtime
- `caddy:latest` — reverse proxy image

<!-- MANUAL: -->
