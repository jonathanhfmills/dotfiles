source /usr/share/cachyos-fish-config/cachyos-config.fish
fish_add_path ~/.local/bin

# bun
set --export BUN_INSTALL "$HOME/.bun"
fish_add_path $BUN_INSTALL/bin

# npm global
fish_add_path $HOME/.npm-global/bin

# Lucid Memory
fish_add_path $HOME/.lucid/bin
