---
name: gamescope
description: Manage gamescope + Steam gaming sessions on Ubuntu 25.10. Build gamescope, start/stop gaming sessions, troubleshoot controller triggers, and optimize performance. Triggers on "gamescope", "steam", "gaming session", "gaming", "controller".
---

# Gamescope + Steam — Ubuntu 25.10

## Architecture

```
Controller BTN_MODE → triggerhappy (thd) → gamescope-start.sh → gamescope + Steam on VT
```

Key files (all in ~/dotfiles):
- `scripts/gamescope-start.sh` — session launcher
- `system/input/gaming-session.conf` — thd trigger config
- `system/systemd/gaming-controller*.service` — systemd units
- Deploy with: `make install-gaming` from ~/dotfiles

## Building Gamescope

Source at `~/gamescope`, version 3.16.15, installed to `/usr/local/bin/gamescope`.

```bash
cd ~/gamescope
meson setup build -Dinput_emulation=enabled
ninja -C build
sudo ninja -C build install
sudo setcap cap_sys_nice+ep /usr/local/bin/gamescope
```

**IMPORTANT:** Reapply `setcap` after every rebuild — the binary is replaced.

### Build Dependencies (Ubuntu 25.10)
- `libeis-dev` (NOT `libei-dev`) — gamescope is a compositor (server), needs the server-side library
- Standard: meson, ninja-build, libwayland-dev, libvulkan-dev, etc.

## Starting a Gaming Session

The controller's home button triggers a gaming session via triggerhappy → systemd:

```bash
# Manual start (for testing)
~/dotfiles/scripts/gamescope-start.sh

# Via systemd
sudo systemctl start gaming-controller-trigger.service
```

## Key Environment Variables

```bash
PIPEWIRE_REMOTE=/dev/null  # Prevents PipeWire from blocking root gamescope
```

## Known Issues (Ubuntu 25.10 Stable)

1. **seatd is VT-bound:** SSH/thd sessions lack a VT → use `openvt -s` to allocate one
2. **PipeWire blocks root gamescope:** Set `PIPEWIRE_REMOTE=/dev/null`
3. **CAP_SYS_NICE:** gamescope needs `setcap cap_sys_nice+ep` on the binary; reapply after rebuild
4. **systemd doesn't expand globs:** use thd `--deviceglob` not bare `/dev/input/event*`
5. **thd doesn't detect hotplug:** udev rule restarts thd via oneshot service when controller plugged in
6. **Stale /usr/local wayland-scanner:** Ubuntu 24.04→25.10 broke it (libxml2.so.2→.so.16); removed, system `/usr/bin` one works

## Still Investigating

- gamescope `-e` (Steam integration) reports "xtest not available, built without libei" at runtime despite libeis.so.1 being linked — may need additional runtime config or rebuild with explicit flag
- NICE errors persisting despite setcap — may need reboot to clear cached binary

## Troubleshooting

```bash
# Check gamescope binary
which gamescope
gamescope --version
getcap /usr/local/bin/gamescope  # Should show cap_sys_nice+ep

# Check triggerhappy
systemctl status gaming-controller-trigger.service
journalctl -u gaming-controller-trigger.service -f

# Check controller events
evtest /dev/input/event*  # Find the controller, watch for BTN_MODE

# Check thd config
cat ~/dotfiles/system/input/gaming-session.conf

# Rebuild and deploy
cd ~/dotfiles && make install-gaming
```

## Dotfiles Deployment

```bash
cd ~/dotfiles
make install-gaming  # Installs udev rules, systemd units, thd config, scripts
```

This copies from `system/` and `scripts/` directories — not managed by stow since these are system-level files.
