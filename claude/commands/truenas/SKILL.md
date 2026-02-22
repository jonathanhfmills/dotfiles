---
name: truenas
description: Manage TrueNAS Scale (hellfireae-nas) via WebSocket JSON-RPC 2.0. Storage pools, SMB shares, apps, services, Caddy reverse proxy, and system administration. Triggers on "truenas", "nas", "caddy", "hellfireae", "smb share", "storage pool".
---

# TrueNAS Scale Management — hellfireae-nas

All commands run from the workstation via the `truenas-ws` WebSocket JSON-RPC 2.0 client. No SSH required.

## CLI Tool

Script location: `~/.claude/skills/truenas/scripts/truenas-ws`

```bash
TWSC=~/.claude/skills/truenas/scripts/truenas-ws

$TWSC ping                              # Test connectivity
$TWSC call <method> ['json_params']     # Single API call
$TWSC job <method> ['json_params']      # Call + track async job to completion
$TWSC subscribe <collection>            # Stream events as JSONL

# Global flags (before subcommand):
#   --timeout N    Request timeout in seconds (default 30)
#   --raw          Compact JSON output (no indentation)
# Job-specific flag:
#   --progress     Show progress updates on stderr
```

Config is auto-loaded from `~/.config/truenas/api.env` (provides `TRUENAS_HOST` and `TRUENAS_API_KEY`).

**IMPORTANT:** All examples below use `truenas-ws` for brevity. Always set `TWSC=~/.claude/skills/truenas/scripts/truenas-ws` first, then use `$TWSC` in place of `truenas-ws`.

## System Info

```bash
truenas-ws ping
truenas-ws call system.info
truenas-ws call system.version
truenas-ws call alert.list
```

## API Discovery

```bash
# List all available methods
truenas-ws call core.get_methods

# Get info about a specific method (params, description)
truenas-ws call core.get_method_info '["app.stop"]'
```

## Storage

```bash
truenas-ws call pool.query
truenas-ws call pool.dataset.query
truenas-ws call disk.query
```

Pool: "Protected" — 2x 1TB NVMe mirror, path `/mnt/Protected`

## SMB Shares

All shares are on `/mnt/Protected/` with guest access enabled.

```bash
# List shares
truenas-ws call sharing.smb.query

# Create share
truenas-ws call sharing.smb.create '[{"path": "/mnt/Protected/NewShare", "name": "NewShare", "guestok": true}]'
```

Existing shares: Downloads, Applications, Documents, Media, Photos, Music, Movies, Shows, Videos, Virtualization

## Services

```bash
# List all services
truenas-ws call service.query

# Start/stop a service
truenas-ws call service.start '["cifs"]'
truenas-ws call service.stop '["cifs"]'
```

Running: cifs (SMB), ssh. Stopped: ftp, iscsi, nfs, snmp, ups, nvmet.

## App Management

```bash
# List all apps
truenas-ws call app.query

# Stop app (tracks job to completion, shows progress)
truenas-ws --timeout 120 job app.stop '["caddy"]' --progress

# Start app
truenas-ws --timeout 120 job app.start '["caddy"]' --progress

# Restart app (stop then start)
truenas-ws --timeout 120 job app.stop '["caddy"]' --progress && \
truenas-ws --timeout 120 job app.start '["caddy"]' --progress
```

Apps: vaultwarden, immich, tailscale, stremio, caddy, adguard-home

## Caddy Reverse Proxy

Caddy runs on standard ports 80/443. Image: `slothcroissant/caddy-cloudflaredns` (auto TLS via Cloudflare DNS challenge).

Caddyfile location: `/mnt/Protected/caddy/etc/Caddyfile`

### Read Caddyfile
```bash
source ~/.config/truenas/api.env
curl -sk -X POST -H "Authorization: Bearer $TRUENAS_API_KEY" -H "Content-Type: application/json" \
  -d '"/mnt/Protected/caddy/etc/Caddyfile"' "$TRUENAS_HOST/api/v2.0/filesystem/get" --output -
```

### Update Caddyfile

**Use REST/curl for file uploads** (WebSocket file upload uses complex binary framing):
```bash
source ~/.config/truenas/api.env
curl -sk -X POST -H "Authorization: Bearer $TRUENAS_API_KEY" \
  -F 'data={"path": "/mnt/Protected/caddy/etc/Caddyfile"};type=application/json' \
  -F "file=@/tmp/Caddyfile;filename=Caddyfile" \
  "$TRUENAS_HOST/api/v2.0/filesystem/put"
```

### Restart Caddy after config change
```bash
truenas-ws --timeout 120 job app.stop '["caddy"]' --progress && \
truenas-ws --timeout 120 job app.start '["caddy"]' --progress
```

Current subdomains (all *.hellfireae.com):
- vault → 11.1.1.10:30032 (Vaultwarden)
- dns → 11.1.1.10:30004 (AdGuard Home)
- stremio → 11.1.1.10:11470 (Stremio Server)
- immich → 11.1.1.10:2283 (Immich)

## Filesystem Operations

```bash
# List directory
truenas-ws call filesystem.listdir '["/mnt/Protected/"]'

# Stat file
truenas-ws call filesystem.stat '["/mnt/Protected/path/to/file"]'

# Read file — use REST curl (binary transfer doesn't work over JSON WebSocket)
source ~/.config/truenas/api.env
curl -sk -X POST -H "Authorization: Bearer $TRUENAS_API_KEY" -H "Content-Type: application/json" \
  -d '"/mnt/Protected/path/to/file"' "$TRUENAS_HOST/api/v2.0/filesystem/get" --output -

# Write file — use REST curl (multipart upload)
curl -sk -X POST -H "Authorization: Bearer $TRUENAS_API_KEY" \
  -F 'data={"path": "/mnt/Protected/path/to/file"};type=application/json' \
  -F "file=@/tmp/localfile;filename=remotename" \
  "$TRUENAS_HOST/api/v2.0/filesystem/put"
```

## Event Subscriptions

```bash
# Stream alert events (Ctrl-C to stop)
truenas-ws subscribe alert.list

# Stream disk events
truenas-ws subscribe disk.query

# Stream app state changes
truenas-ws subscribe app.query
```

## API Gotchas

1. **Params are JSON arrays** — `'["caddy"]'` not `'"caddy"'`
2. **Use `job` for async operations** — app stop/start, pool scrub, updates, etc.
3. **File read/write uses REST curl** — `filesystem.get` and `filesystem.put` transfer binary data that doesn't work over JSON WebSocket
4. **Global flags before subcommand** — `truenas-ws --timeout 120 job ...` not `truenas-ws job ... --timeout 120`
5. **Port changes are dangerous** — if you set UI port to one already in use, API becomes unreachable
6. **Web UI ports** — HTTPS: 8783 (TRUE in T9), HTTP: 627 (NAS in T9)
