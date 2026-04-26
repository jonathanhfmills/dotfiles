.PHONY: install stow unstow update

PACKAGES = agents git zsh npm local

install: deps stow

deps:
	sudo pacman -S --noconfirm stow python-yaml git

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
