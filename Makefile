.PHONY: install update apt apt-repos gh php composer pwsh nvm node bun claude npm-globals omc sandbox-runtime codex gemini qwen claude-plugins docker lucid link proxy ssh 1password-ssh-agent

SHELL := /bin/bash
NVM_DIR := $(HOME)/.nvm
NODE_VERSION := 24

install: apt gh php composer pwsh nvm node claude npm-globals claude-plugins docker link

# ── Update ───────────────────────────────────────────────────────────────────
update:
	sudo apt-get update && sudo apt-get upgrade -y

# ── System packages ──────────────────────────────────────────────────────────
apt:
	sudo apt-get update -qq
	sudo apt-get install -y jq tmux git curl make stow bubblewrap socat unzip ripgrep

# ── Third-party apt repos ─────────────────────────────────────────────────────
apt-repos: apt
	@sudo mkdir -p -m 755 /etc/apt/keyrings /etc/apt/sources.list.d
	@# GitHub CLI
	@if [ ! -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]; then \
		type -p wget >/dev/null || sudo apt-get install -y wget; \
		out=$$(mktemp) && wget -nv -O$$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
			&& cat $$out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null; \
		sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
			| sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null; \
		echo "GitHub CLI repo registered"; \
	fi
	@# Claude Code
	@if [ ! -f /etc/apt/keyrings/claude-code.asc ]; then \
		sudo curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
			-o /etc/apt/keyrings/claude-code.asc; \
		echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
			| sudo tee /etc/apt/sources.list.d/claude-code.list > /dev/null; \
		echo "Claude Code repo registered"; \
	fi
	@# Docker
	@if [ ! -f /etc/apt/keyrings/docker.asc ]; then \
		sudo apt-get install -y ca-certificates; \
		sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
		sudo chmod a+r /etc/apt/keyrings/docker.asc; \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$$VERSION_CODENAME}") stable" \
			| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; \
		echo "Docker repo registered"; \
	fi
	@sudo apt-get update -qq

# ── GitHub CLI ───────────────────────────────────────────────────────────────
gh: apt-repos
	@if ! command -v gh &>/dev/null; then \
		sudo apt-get install -y gh; \
	else \
		echo "gh already installed: $$(gh --version | head -1)"; \
	fi

# ── PowerShell ───────────────────────────────────────────────────────────────
pwsh:
	@if ! command -v pwsh &>/dev/null; then \
		sudo apt-get install -y wget apt-transport-https software-properties-common; \
		source /etc/os-release; \
		wget -q https://packages.microsoft.com/config/ubuntu/$$VERSION_ID/packages-microsoft-prod.deb; \
		sudo dpkg -i packages-microsoft-prod.deb; \
		rm packages-microsoft-prod.deb; \
		sudo apt-get update -qq && sudo apt-get install -y powershell; \
	else \
		echo "pwsh already installed: $$(pwsh --version)"; \
	fi

# ── PHP ──────────────────────────────────────────────────────────────────────
php:
	@if ! command -v php &>/dev/null; then \
		sudo apt-get update -qq && sudo apt-get install -y php-fpm php-cli php-mbstring php-xml php-curl unzip; \
	else \
		echo "php already installed: $$(php --version | head -1)"; \
	fi

# ── Composer ─────────────────────────────────────────────────────────────────
composer: php
	@if ! command -v composer &>/dev/null; then \
		sudo apt-get install -y composer; \
	else \
		echo "composer already installed: $$(composer --version)"; \
	fi

# ── Node via nvm ─────────────────────────────────────────────────────────────
nvm:
	@if [ ! -f "$(NVM_DIR)/nvm.sh" ]; then \
		curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash; \
	else \
		echo "nvm already installed"; \
	fi

node: nvm
	@source "$(NVM_DIR)/nvm.sh" && \
	if ! nvm ls $(NODE_VERSION) | grep -q "v$(NODE_VERSION)"; then \
		nvm install $(NODE_VERSION); \
	fi && \
	nvm use $(NODE_VERSION) && \
	nvm alias default $(NODE_VERSION)

# ── Claude Code CLI ───────────────────────────────────────────────────────────
claude: apt-repos
	@if ! command -v claude &>/dev/null; then \
		sudo apt-get install -y claude-code; \
	else \
		echo "claude already installed: $$(claude --version 2>/dev/null | head -1)"; \
	fi

# ── npm global packages ───────────────────────────────────────────────────────
npm-globals: node sandbox-runtime

omc: node
	@source "$(NVM_DIR)/nvm.sh" && npm install -g oh-my-claude-sisyphus

sandbox-runtime: node
	@source "$(NVM_DIR)/nvm.sh" && npm install -g @anthropic-ai/sandbox-runtime

codex: node
	@source "$(NVM_DIR)/nvm.sh" && npm install -g @openai/codex

gemini: node
	@source "$(NVM_DIR)/nvm.sh" && npm install -g @google/gemini-cli@latest

qwen: node
	@source "$(NVM_DIR)/nvm.sh" && npm install -g @qwen-code/qwen-code@latest

# ── Claude Code plugins ───────────────────────────────────────────────────────
claude-plugins: claude
	claude plugin marketplace add https://github.com/JuliusBrussee/caveman
	claude plugin install caveman
	claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode
	claude plugin install oh-my-claudecode

# ── Docker Engine ────────────────────────────────────────────────────────────
docker: apt-repos
	@if ! command -v docker &>/dev/null; then \
		sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
		sudo usermod -aG docker $$USER; \
		echo "Docker installed. Restart WSL to apply group membership."; \
	else \
		echo "docker already installed: $$(docker --version)"; \
	fi

# ── Bun ──────────────────────────────────────────────────────────────────────
bun:
	@if ! command -v bun &>/dev/null; then \
		curl -fsSL https://bun.sh/install | bash; \
	else \
		echo "bun already installed: $$(bun --version)"; \
	fi

# ── Lucid Memory (MCP memory for Claude Code) ────────────────────────────────
lucid: bun
	@if [ ! -d "$(HOME)/.lucid" ]; then \
		sudo apt-get install -y python3-pip ffmpeg yt-dlp; \
		pip3 install --break-system-packages openai-whisper; \
		curl -fsSL https://lucidmemory.dev/install | bash; \
	else \
		echo "lucid already installed"; \
	fi

# ── 1Password SSH Agent Bridge (WSL side) ────────────────────────────────────
1password-ssh-agent: ssh
	@# Stow shell config (bridge script, systemd service, .bashrc.d snippet)
	@# --no-folding prevents stow from symlinking dirs, keeping systemd writes out of the source tree
	stow --no-folding -d "$(CURDIR)" -t "$(HOME)" shell
	@chmod +x "$(HOME)/.local/bin/1password-ssh-agent-bridge"
	@# Download npiperelay.exe to Windows user's bin (bridges named pipe → socat)
	@WINDOWS_USER=$$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n '); \
	WINDOWS_BIN="/mnt/c/Users/$$WINDOWS_USER/bin"; \
	mkdir -p "$$WINDOWS_BIN"; \
	if [ ! -f "$$WINDOWS_BIN/npiperelay.exe" ]; then \
		curl -fsSL -o /tmp/npiperelay.zip \
			"https://github.com/jstarks/npiperelay/releases/latest/download/npiperelay_windows_amd64.zip"; \
		unzip -oj /tmp/npiperelay.zip npiperelay.exe -d "$$WINDOWS_BIN/"; \
		rm -f /tmp/npiperelay.zip; \
		echo "npiperelay.exe installed to $$WINDOWS_BIN"; \
	else \
		echo "npiperelay.exe already installed"; \
	fi
	@# Allow SSH daemon to pass SSH_AUTH_SOCK to non-interactive sessions
	@if ! grep -q 'PermitUserEnvironment' /etc/ssh/sshd_config.d/99-wsl.conf 2>/dev/null; then \
		printf 'PermitUserEnvironment yes\n' | sudo tee -a /etc/ssh/sshd_config.d/99-wsl.conf > /dev/null; \
		sudo systemctl restart ssh; \
	fi
	@# Persist SSH_AUTH_SOCK for non-interactive SSH sessions (e.g. claude mcp serve)
	@mkdir -p "$(HOME)/.ssh" && chmod 700 "$(HOME)/.ssh"
	@grep -q 'SSH_AUTH_SOCK' "$(HOME)/.ssh/environment" 2>/dev/null || \
		{ echo "SSH_AUTH_SOCK=$(HOME)/.1password/agent.sock" >> "$(HOME)/.ssh/environment"; \
		  chmod 600 "$(HOME)/.ssh/environment"; }
	@# Wire .bashrc.d/ into .bashrc for interactive shells
	@grep -q '\.bashrc\.d' "$(HOME)/.bashrc" 2>/dev/null || \
		printf '\nfor f in ~/.bashrc.d/*.sh; do [ -f "$$f" ] && source "$$f"; done\n' >> "$(HOME)/.bashrc"
	@# Enable persistent systemd user service
	systemctl --user enable --now 1password-ssh-agent
	@echo "1Password SSH agent bridge active at $(HOME)/.1password/agent.sock"

# ── SSH Server (WSL → Claude Desktop MCP over SSH) ───────────────────────────
ssh:
	@if ! dpkg -l openssh-server 2>/dev/null | grep -q '^ii'; then \
		sudo apt-get install -y openssh-server; \
	else \
		echo "openssh-server already installed"; \
	fi
	@printf 'Port 2222\nPasswordAuthentication no\n' | sudo tee /etc/ssh/sshd_config.d/99-wsl.conf > /dev/null
	@sudo systemctl enable --now ssh
	@echo "SSH running on port 2222 (key auth only)"
	@echo "Add Windows public key to ~/.ssh/authorized_keys"
	@echo "Claude Desktop config: host=localhost, port=2222, user=$$(whoami), command=claude mcp serve"

# ── Reverse proxy ────────────────────────────────────────────────────────────
proxy:
	docker compose -f "$(CURDIR)/proxy/docker-compose.yml" up -d

# ── Symlink dotfiles via stow ─────────────────────────────────────────────────
link:
	@if [ ! -f "$(CURDIR)/git/.gitconfig" ]; then \
		cp "$(CURDIR)/git/.gitconfig.example" "$(CURDIR)/git/.gitconfig"; \
		echo "Created git/.gitconfig from example — fill in your personal settings before continuing"; \
	fi
	stow -d "$(CURDIR)" -t "$(HOME)" tmux git
	stow -d "$(CURDIR)" -t "$(HOME)/.claude" .claude
	stow -d "$(CURDIR)" -t "$(HOME)/.codex" .codex
	stow -d "$(CURDIR)" -t "$(HOME)/.gemini" .gemini
	stow -d "$(CURDIR)" -t "$(HOME)/.qwen" .qwen
	@echo "Run 'make 1password-ssh-agent' to also stow shell/ and set up the 1Password SSH bridge"
