.PHONY: rebuild update sync test check

rebuild:
	./scripts/sync-dotfiles.sh pull
	sudo nixos-rebuild switch --flake .#desktop
	./scripts/sync-dotfiles.sh push

update:
	nix flake update
	$(MAKE) rebuild

sync:
	./scripts/sync-dotfiles.sh

test:
	nixos-rebuild build --flake .#desktop

check:
	nix flake check
