# Idempotent bootstrap for WSL2/Ubuntu dev environments.
# Run `make install` on a fresh machine to install all default tools and symlink dotfiles.
# Run `make update` to upgrade all installed apt packages.

.PHONY: install update apt apt-repos gh az azd func php composer pwsh nvm node bun claude npm-globals sisyphus sandbox-runtime codex gemini qwen claude-plugins docker lucid ssh link proxy

SHELL := /bin/bash
NVM_DIR := $(HOME)/.nvm
NODE_VERSION := 24

install: apt gh az azd func php composer pwsh nvm node claude npm-globals claude-plugins docker lucid ssh link

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
	@# Microsoft (Azure Functions Core Tools)
	@if [ ! -f /etc/apt/trusted.gpg.d/microsoft.gpg ]; then \
		curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
			| gpg --dearmor \
			| sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null; \
		echo "deb [arch=$$(dpkg --print-architecture)] https://packages.microsoft.com/repos/microsoft-ubuntu-$$(lsb_release -cs)-prod $$(lsb_release -cs) main" \
			| sudo tee /etc/apt/sources.list.d/dotnetdev.list > /dev/null; \
		echo "Microsoft repo registered"; \
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

# ── Azure CLI ────────────────────────────────────────────────────────────────
az:
	@if ! command -v az &>/dev/null; then \
		curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash; \
	else \
		echo "az already installed: $$(az --version | head -1)"; \
	fi

# ── Azure Developer CLI ──────────────────────────────────────────────────────
azd:
	@if ! command -v azd &>/dev/null; then \
		curl -fsSL https://aka.ms/install-azd.sh | bash; \
	else \
		echo "azd already installed: $$(azd version)"; \
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

# ── Azure Functions Core Tools ───────────────────────────────────────────────
func: apt-repos
	@if ! command -v func &>/dev/null; then \
		sudo apt-get install -y azure-functions-core-tools-4; \
	else \
		echo "func already installed: $$(func --version)"; \
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
		php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"; \
		sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer; \
		rm /tmp/composer-setup.php; \
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

sisyphus: node
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

# ── SSH setup ────────────────────────────────────────────────────────────────
ssh:
	@mkdir -p $(HOME)/.ssh && chmod 700 $(HOME)/.ssh
	@if ! grep -q ssh.dev.azure.com $(HOME)/.ssh/known_hosts 2>/dev/null; then \
		ssh-keyscan ssh.dev.azure.com >> $(HOME)/.ssh/known_hosts; \
	else \
		echo "ssh.dev.azure.com already in known_hosts"; \
	fi

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
