.PHONY: install update apt apt-repos gh php composer pwsh nvm node bun claude npm-globals omc sandbox-runtime codex gemini qwen claude-plugins docker lucid link proxy ssh go-runtime rust-runtime dotnet-runtime lsp-servers claude-lsp-plugins

SHELL := /bin/bash
NVM_DIR := $(HOME)/.nvm
NODE_VERSION := 24
GO_VERSION := 1.24.3

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

# ── SSH Server (WSL → Claude Desktop Remote) ─────────────────────────────────
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

# ── Go runtime ───────────────────────────────────────────────────────────────
go-runtime:
	@if ! [ -x /usr/local/go/bin/go ]; then \
		curl -fsSL https://go.dev/dl/go$(GO_VERSION).linux-amd64.tar.gz -o /tmp/go.tar.gz; \
		sudo rm -rf /usr/local/go; \
		sudo tar -C /usr/local -xzf /tmp/go.tar.gz; \
		rm /tmp/go.tar.gz; \
		echo "Go $(GO_VERSION) installed"; \
	else \
		echo "go already installed: $$(/usr/local/go/bin/go version)"; \
	fi

# ── Rust runtime ─────────────────────────────────────────────────────────────
rust-runtime:
	@if ! [ -x "$(HOME)/.cargo/bin/rustc" ]; then \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path; \
		echo "Rust installed"; \
	else \
		echo "rust already installed: $$($(HOME)/.cargo/bin/rustc --version)"; \
	fi

# ── .NET runtime ─────────────────────────────────────────────────────────────
# Installs .NET LTS (current) + .NET 8 (required for csharp-ls compatibility).
dotnet-runtime:
	@if ! [ -x "$(HOME)/.dotnet/dotnet" ]; then \
		curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel LTS; \
		echo ".NET LTS installed"; \
	else \
		echo "dotnet already installed: $$($(HOME)/.dotnet/dotnet --version)"; \
	fi
	@if ! $(HOME)/.dotnet/dotnet --list-sdks 2>/dev/null | grep -q "^8\."; then \
		curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0; \
		echo ".NET 8 SDK installed (required for csharp-ls)"; \
	else \
		echo "dotnet 8 SDK already installed"; \
	fi
	@ln -sf $(HOME)/.dotnet/dotnet $(HOME)/.local/bin/dotnet

# ── LSP servers (opt-in: make lsp-servers) ───────────────────────────────────
# Installs all LSP binaries into ~/.local/bin (already in PATH).
# Tested: clangd, typescript-ls, rust-analyzer, jdtls, lua-ls, gopls, ty (Python).
# csharp-ls works but ~30s WSL2 init time (known .NET cold-start on WSL2).
# kotlin-lsp: JetBrains binary Linux-unavailable (macOS/Homebrew only).
# swift-lsp: requires full Swift toolchain from swift.org (~600MB).
lsp-servers: go-runtime rust-runtime dotnet-runtime node
	@mkdir -p $(HOME)/.local/bin $(HOME)/.local/share
	@# clangd (C/C++)
	@if ! command -v clangd &>/dev/null; then sudo apt-get install -y clangd; fi
	@# Java (required for jdtls)
	@if ! command -v java &>/dev/null; then sudo apt-get install -y default-jdk; fi
	@# npm-based LSPs: bash, PHP, TypeScript
	@source "$(NVM_DIR)/nvm.sh" && npm install -g \
		bash-language-server \
		intelephense \
		typescript \
		typescript-language-server
	@# ty (Python LSP — required by pyright-lsp plugin)
	@if ! [ -x "$(HOME)/.local/bin/ty" ]; then \
		TY_URL=$$(curl -fsSL -H "User-Agent: dotfiles-installer" \
			https://api.github.com/repos/astral-sh/ty/releases/latest | \
			python3 -c "import sys,json; d=json.load(sys.stdin); \
			print(next(a['browser_download_url'] for a in d['assets'] if 'linux' in a['name'] and 'x86_64' in a['name'] and a['name'].endswith('.tar.gz')))"); \
		curl -fsSL "$$TY_URL" | tar -xz -C $(HOME)/.local/share; \
		ln -sf $$(find $(HOME)/.local/share -name "ty" -type f -path "*/ty-*/ty" 2>/dev/null | head -1) $(HOME)/.local/bin/ty; \
	else echo "ty already installed: $$($(HOME)/.local/bin/ty --version)"; fi
	@# gopls (Go LSP)
	@if ! [ -f "$(HOME)/go/bin/gopls" ]; then \
		GOPATH=$(HOME)/go GOBIN=$(HOME)/go/bin /usr/local/go/bin/go install golang.org/x/tools/gopls@latest; \
	else echo "gopls already installed"; fi
	@ln -sf $(HOME)/go/bin/gopls $(HOME)/.local/bin/gopls
	@# rust-analyzer
	@$(HOME)/.cargo/bin/rustup component add rust-analyzer
	@ln -sf $(HOME)/.cargo/bin/rust-analyzer $(HOME)/.local/bin/rust-analyzer
	@# csharp-ls (.NET LSP) — wrapper sets DOTNET_ROOT (required on WSL2)
	@if ! [ -f "$(HOME)/.dotnet/tools/csharp-ls" ]; then \
		DOTNET_ROOT=$(HOME)/.dotnet $(HOME)/.dotnet/dotnet tool install --global csharp-ls; \
	else echo "csharp-ls already installed"; fi
	@printf '#!/bin/bash\nexport DOTNET_ROOT="$$HOME/.dotnet"\nexport PATH="$$HOME/.dotnet:$$HOME/.dotnet/tools:$$PATH"\nexec "$$HOME/.dotnet/tools/csharp-ls" "$$@"\n' \
		> $(HOME)/.local/bin/csharp-ls && chmod +x $(HOME)/.local/bin/csharp-ls
	@# jdtls (Java LSP) — from Eclipse download server
	@if ! [ -d "$(HOME)/.local/share/jdtls" ]; then \
		mkdir -p $(HOME)/.local/share/jdtls; \
		curl -fsSL https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz \
			| tar -xz -C $(HOME)/.local/share/jdtls; \
	else echo "jdtls already installed"; fi
	@ln -sf $(HOME)/.local/share/jdtls/bin/jdtls $(HOME)/.local/bin/jdtls
	@# lua-language-server — from GitHub releases
	@if ! [ -f "$(HOME)/.local/share/lua-language-server/bin/lua-language-server" ]; then \
		LUA_URL=$$(curl -fsSL -H "User-Agent: dotfiles-installer" \
			https://api.github.com/repos/LuaLS/lua-language-server/releases/latest | \
			python3 -c "import sys,json; d=json.load(sys.stdin); \
			print(next(a['browser_download_url'] for a in d['assets'] if 'linux-x64' in a['name'] and a['name'].endswith('.tar.gz')))"); \
		mkdir -p $(HOME)/.local/share/lua-language-server; \
		curl -fsSL "$$LUA_URL" | tar -xz -C $(HOME)/.local/share/lua-language-server; \
	else echo "lua-language-server already installed"; fi
	@ln -sf $(HOME)/.local/share/lua-language-server/bin/lua-language-server $(HOME)/.local/bin/lua-language-server
	@echo "LSP servers installed. Binaries in ~/.local/bin"
	@echo "Note: kotlin-lsp (no Linux binary) and swift-lsp (needs Swift toolchain) require manual install"

# ── Claude Code LSP plugins (opt-in: make claude-lsp-plugins) ────────────────
# Uses the official claude-plugins-official marketplace (registered by default).
# swift-lsp included for completeness; sourcekit-lsp binary requires Swift toolchain.
claude-lsp-plugins: claude
	@for plugin in clangd-lsp csharp-lsp gopls-lsp jdtls-lsp kotlin-lsp lua-lsp php-lsp pyright-lsp rust-analyzer-lsp swift-lsp typescript-lsp; do \
		claude plugin install $$plugin 2>/dev/null || true; \
	done
	@echo "Claude LSP plugins installed"

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
