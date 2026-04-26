.PHONY: install stow unstow update

PACKAGES = agents git zsh npm local

install: deps stow

deps: paru-install
	sudo pacman -S --noconfirm stow python-yaml git nodejs npm docker github-cli
	sudo systemctl enable --now docker
	sudo usermod -aG docker $$USER
	curl -LsSf https://astral.sh/uv/install.sh | sh
	paru -S --noconfirm 1password microsoft-edge-stable-bin
	npm install -g @anthropic-ai/claude-code

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
