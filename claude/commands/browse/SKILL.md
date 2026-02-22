---
name: browse
description: >-
  Dockerized Chromium browser for web browsing and QA auditing.
  Navigate pages, interact with forms, read rendered HTML, run Lighthouse/a11y/SEO/WordPress/GTM audits.
  Triggers on "browse", "visit", "open url", "audit site", "qa check", "lighthouse", "web page".
---

# Browse — AI Browser & QA Playbook

A full Chromium browser running in Docker. Two modes:
1. **General browsing** — read docs, research, view any page with full JS rendering
2. **QA auditing** — standardized playbook for WordPress site audits

## Tool Location

```
~/.claude/skills/browse/scripts/browse
```

## Commands

### `browse go URL [flags]`

Navigate to a URL and return rendered content. Uses a **persistent browser profile** — logins, cookies, preferences survive between runs.

**Default output is HTML + text only** (no screenshots). Token-efficient for routine browsing.

```bash
# Basic page fetch (like a better WebFetch with JS rendering)
browse go "https://playwright.dev/docs/api/class-page"

# Mobile device emulation
browse go "https://cosmickmedia.com" --device "iPhone 15"

# With screenshot
browse go "https://cosmickmedia.com" --device "iPhone 15" --screenshot

# Page interactions
browse go "https://site.com/contact" --click "button[type=submit]"
browse go "https://site.com/login" --type "#user=admin" --type "#pass=test" --click "#login" --screenshot

# Wait for SPA content
browse go "https://site.com/" --wait networkidle

# Complex multi-step via JSON stdin
echo '{"url":"https://site.com/wp-login.php","actions":[{"type":{"selector":"#user_login","text":"admin"}},{"type":{"selector":"#user_pass","text":"pass"}},{"click":"#wp-submit"},{"wait":"networkidle"}],"screenshot":true}' | browse go --stdin
```

**Flags:**
| Flag | Description |
|------|-------------|
| `--device NAME` | Playwright device profile (e.g., "iPhone 15", "iPad Mini", "Pixel 7") |
| `--screenshot` | Save full-page screenshot |
| `--click SELECTOR` | Click an element (repeatable) |
| `--type SEL=TEXT` | Fill a form field (repeatable) |
| `--wait STRATEGY` | `networkidle`, `load`, or `domcontentloaded` |
| `--timeout MS` | Navigation timeout (default 30000) |
| `--stdin` | Read JSON input from stdin |

**Output:** JSON with `{success, url, finalUrl, title, status, html, text, consoleErrors, device, timing, screenshotPath}`

### `browse audit URL [--device NAME]`

Run a full QA audit. Uses an **ephemeral browser** (clean baseline every time).

```bash
browse audit "https://cosmickmedia.com"
browse audit "https://clientsite.com" --device "iPhone 15"
```

**Checks performed:**
1. **Lighthouse** — Performance, Accessibility, Best Practices, SEO (0-100 scores)
2. **axe-core accessibility** — WCAG violations with severity and DOM node count
3. **SEO meta** — title, description, canonical, robots, Open Graph, Twitter cards, JSON-LD
4. **Heading structure** — H1-H6 hierarchy, missing/duplicate H1, skipped levels
5. **WordPress** — version exposure, login page, XML-RPC, REST API users, plugin errors, security headers
6. **Google Tag Manager** — container ID, dataLayer, noscript fallback
7. **SSL & redirects** — HTTP→HTTPS, certificate validity
8. **Console errors** — all browser errors during page load

**Output:** JSON with all check results. Pure structured data — no screenshots, no wasted tokens.

### `browse test [args]`

Run Playwright test specs from `~/dotfiles/playwright/tests/`.

```bash
browse test
browse test --grep "loads"
browse test tests/cosmickmedia.spec.ts
```

### `browse clear DOMAIN`

Clear cookies and storage for a specific domain in the persistent profile.

```bash
browse clear cosmickmedia.com
browse clear clientsite.com
```

**Clears:** cookies, localStorage, sessionStorage, IndexedDB, service workers.

### `browse build`

Rebuild the Docker image (after code changes).

```bash
browse build
```

## Device Emulation

Both `go` and `audit` accept `--device NAME`. Key profiles:

| Device | Width | Type |
|--------|-------|------|
| Desktop Chrome | 1280px | Desktop (default) |
| iPhone 15 | 393px | Mobile |
| iPhone 15 Pro Max | 430px | Mobile (large) |
| Pixel 7 | 412px | Android |
| iPad Mini | 768px | Tablet |
| iPad Pro 11 | 834px | Tablet (large) |
| Desktop Chrome HiDPI | 1280px @2x | Retina |

## Screenshots

Screenshots save to `/tmp/playwright-screenshots/` on the host. Read them with the Read tool.

## Architecture

- **Docker image**: `mcr.microsoft.com/playwright:v1.50.0-noble` + Lighthouse + axe-core
- **Persistent profile**: Docker named volume `profile-data` (survives rebuilds)
- **Network**: `host` mode (access internet + homelab)
- **Source**: `~/dotfiles/playwright/` (TypeScript → compiled in image)

## QA Playbook for Client Sites

The `audit` command is the standardized playbook. For Cosmick Media's ~400 WordPress sites:

1. Run `browse audit "https://clientsite.com"` — same checks for every site
2. Parse JSON output — which checks passed, which failed?
3. Flag failures with specific details (e.g., "missing H1", "xmlrpc enabled", "no GTM")
4. Fix and re-audit to confirm

Every site gets the same treatment. JSON output makes batch processing trivial.
