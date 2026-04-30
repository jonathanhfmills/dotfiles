# Security Policy

## Sensitive Data Handling

This repository contains no secrets, credentials, or personal data. The following files are explicitly excluded from version control:

| Path | Reason |
|------|--------|
| `git/.gitconfig` | Contains user identity, email, and SSH signing key |
| `.claude/settings.local.json` | Local Claude Code configuration |
| `.omc/` | Session and state data |

The tracked `git/.gitconfig.example` contains placeholder values only. Developers must populate `git/.gitconfig` locally and must not commit it.

## Supply Chain Integrity

All third-party software is installed from official, GPG-signed sources:

| Tool | Source |
|------|--------|
| GitHub CLI | `cli.github.com/packages` — signed keyring |
| Claude Code | `downloads.claude.ai` — signed ASC key |
| Azure CLI | `aka.ms/InstallAzureCLIDeb` — official Microsoft script |
| Azure Developer CLI | `aka.ms/install-azd.sh` — official Microsoft script |
| Azure Functions Core Tools | `packages.microsoft.com` — signed GPG key |
| Docker | `download.docker.com` — signed ASC key |
| PowerShell | `packages.microsoft.com` — Microsoft prod package |
| Composer | `getcomposer.org/installer` — official PHP installer |

No Makefile targets fetch from unverified sources.

## Access Control

- All commits are SSH-signed (configured per developer in `git/.gitconfig`)
- GitHub credential helper uses `gh auth git-credential` — no stored plaintext tokens

## AI Tool Isolation (WSL)

Running AI coding agents (Claude Code, Codex, Gemini CLI, Qwen Code) inside WSL rather than directly on Windows provides meaningful security isolation:

- **Filesystem boundary** — agents operate within the Linux filesystem by default; Windows drives are accessible only via explicit `/mnt/c/` paths, reducing accidental or unintended access to Windows user data, app data, and registry
- **Process isolation** — agent processes cannot directly spawn Windows-native processes or access Windows credential stores, COM interfaces, or the Windows token
- **Network namespace** — WSL2 runs in a lightweight VM with its own network stack; agent traffic does not share the Windows network namespace
- **Blast radius containment** — if an agent executes malicious or runaway code, damage is scoped to the WSL instance and its mounted volumes, not the host Windows environment
- **Credential separation** — SSH keys and API tokens configured in WSL are not the same credentials used by Windows applications; compromise of one does not imply compromise of the other

This makes WSL the preferred execution environment for AI agents on Windows development machines.

## Reporting a Vulnerability

Contact the relevant maintainer directly. Do not open a public GitHub issue for security vulnerabilities.

## SOC 2 Relevance

| Control | Implementation |
|---------|---------------|
| CC6.1 — Access control | Secrets gitignored; SSH commit signing required |
| CC6.7 — Transmission protection | All downloads over TLS; GPG-verified apt keys |
| CC8.1 — Change management | All changes committed; signed commits enforced |
| CC9.2 — Supply chain risk | Official vendor sources only; no unverified scripts |
