.PHONY: install stow unstow update hooks

PACKAGES = agents git zsh npm local fish opensandbox weechat

install: deps stow hooks

hooks:
	@for hook in post-commit post-merge post-checkout post-rewrite pre-push; do \
		cp $(CURDIR)/git-hooks/$$hook $(CURDIR)/.git/hooks/$$hook; \
		chmod +x $(CURDIR)/.git/hooks/$$hook; \
	done
	@echo "hooks installed"

deps: paru-install
	sudo -v
	sudo pacman -S --needed --noconfirm stow python-yaml git nodejs npm docker docker-compose github-cli weechat
	sudo systemctl enable --now docker
	sudo usermod -aG docker $$USER
	@which uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
	@paru -Q inspircd >/dev/null 2>&1 || paru -S --noconfirm inspircd
	sudo mkdir -p /var/lib/inspircd /var/log/inspircd
	sudo chown inspircd:inspircd /var/lib/inspircd /var/log/inspircd
	@test -f /etc/inspircd/inspircd.conf || sudo cp $(CURDIR)/inspircd/etc/inspircd/inspircd.conf /etc/inspircd/inspircd.conf
	sudo systemctl enable --now inspircd
	@paru -Q 1password >/dev/null 2>&1 || paru -S --noconfirm 1password
	@paru -Q microsoft-edge-stable-bin >/dev/null 2>&1 || paru -S --noconfirm microsoft-edge-stable-bin
	@which claude >/dev/null 2>&1 || npm install -g @anthropic-ai/claude-code
	@which huggingface-cli >/dev/null 2>&1 || uv tool install huggingface-hub
	@which docker-compose >/dev/null 2>&1 || sudo pacman -S --noconfirm docker-compose
	cd $(CURDIR) && docker-compose up -d ollama inspircd
	docker exec ollama ollama pull qwen3.5:9b-q8_0
	@which yt-dlp >/dev/null 2>&1 || uv tool install yt-dlp
	@which whisper >/dev/null 2>&1 || uv tool install openai-whisper
	@which lucid >/dev/null 2>&1 || curl -fsSL https://lucidmemory.dev/install | bash
	@which omc >/dev/null 2>&1 || npm install -g oh-my-claude-sisyphus
	@which osb >/dev/null 2>&1 || uv tool install opensandbox-cli
	@test -f $(CURDIR)/opensandbox/.venv/bin/python || ( python3 -m venv $(CURDIR)/opensandbox/.venv && $(CURDIR)/opensandbox/.venv/bin/pip install -q opensandbox )

paru-install:
	@which paru >/dev/null 2>&1 || ( \
		sudo pacman -S --noconfirm base-devel && \
		git clone https://aur.archlinux.org/paru.git /tmp/paru && \
		cd /tmp/paru && makepkg -si --noconfirm \
	)

stow:
	@for pkg in $(PACKAGES); do \
		echo "stowing $$pkg..."; \
		stow $$pkg || true; \
	done
	@stow -R git --override='.gitignore' 2>/dev/null || true

unstow:
	@for pkg in $(PACKAGES); do \
		stow -D $$pkg 2>/dev/null || true; \
	done

update:
	git pull && $(MAKE) stow
