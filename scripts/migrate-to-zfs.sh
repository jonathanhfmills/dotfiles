#!/usr/bin/env bash
#
# migrate-to-zfs.sh — Shrink ext4, create ZFS pool, install NixOS on ZFS.
#
# RUN THIS FROM THE NIXOS LIVE USB, NOT THE INSTALLED SYSTEM.
#
# Prerequisites:
#   - Booted from NixOS 25.11 graphical live USB
#   - Internet connectivity (for nix packages and flake inputs)
#   - External backup drive verified
#
# This script is designed to be run step-by-step. Each phase prompts
# for confirmation before proceeding.
#
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────

# Disk identifier (stable by-id path).
DISK="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4P4NG0M101390D"

# Partition numbers.
EFI_PART="${DISK}-part1"       # Existing 1GB EFI, keep as-is
EXT4_PART="${DISK}-part2"      # Existing ext4 root, will shrink
OLD_SWAP_PART="${DISK}-part3"  # Existing swap, will delete
ZFS_PART="${DISK}-part4"       # New ZFS partition

# Target sizes.
EXT4_SHRINK_SIZE="95G"         # Shrink ext4 filesystem to this (leaves headroom in 100GB partition)
EXT4_PART_SECTORS=209715200    # 100GB in 512-byte sectors
EXT4_PART_START=2101248        # Current start sector (don't change)
EXT4_PART_END=$((EXT4_PART_START + EXT4_PART_SECTORS - 1))  # = 211816447

# ZFS partition fills remaining space.
ZFS_PART_START=$((EXT4_PART_END + 1))  # = 211816448 (already 1MB-aligned)

# ZFS pool name.
POOL="rpool"

# NixOS flake config name.
FLAKE_CONFIG="desktop-zfs"

# Colors for output.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }

confirm() {
    local msg="$1"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $msg${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -rp "  Continue? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { error "Aborted."; exit 1; }
    echo ""
}

# ─────────────────────────────────────────────────────────────────────
# Phase 0: Preflight checks
# ─────────────────────────────────────────────────────────────────────

phase0_preflight() {
    info "Phase 0: Preflight checks"

    # Must be root.
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)."
        exit 1
    fi

    # Must be in live environment (root should not be on the NVMe).
    local root_dev
    root_dev=$(findmnt -n -o SOURCE / 2>/dev/null || true)
    if [[ "$root_dev" == *nvme0n1* ]]; then
        error "You appear to be running on the installed system, not the live USB."
        error "Boot from the NixOS live USB first!"
        exit 1
    fi

    # Check disk exists.
    if [[ ! -e "$DISK" ]]; then
        error "Disk not found: $DISK"
        error "Available disks:"
        ls -la /dev/disk/by-id/ | grep -i nvme
        exit 1
    fi

    # Make sure no NVMe partitions are mounted.
    if mount | grep -q nvme0n1; then
        error "NVMe partitions are still mounted. Unmount them first:"
        mount | grep nvme0n1
        exit 1
    fi

    # Make sure swap on NVMe is off.
    if swapon --show | grep -q nvme0n1; then
        error "Swap is active on NVMe. Run: swapoff ${OLD_SWAP_PART}"
        exit 1
    fi

    success "Preflight checks passed."
    echo ""
    info "Current partition layout:"
    fdisk -l /dev/nvme0n1
    echo ""
    info "Target layout:"
    echo "  p1: 1GB EFI (keep)     sectors 4096–2101247"
    echo "  p2: 100GB ext4 (shrink) sectors ${EXT4_PART_START}–${EXT4_PART_END}"
    echo "  p3: (deleted)"
    echo "  p4: ~830GB ZFS (new)   sectors ${ZFS_PART_START}–end"
}

# ─────────────────────────────────────────────────────────────────────
# Phase 1: Install ZFS in the live environment
# ─────────────────────────────────────────────────────────────────────

phase1_install_zfs() {
    info "Phase 1: Installing ZFS tools in the live environment"

    if command -v zpool &>/dev/null; then
        success "ZFS tools already available."
    else
        info "Installing ZFS packages (this may take a minute)..."
        nix-env -iA nixos.zfs nixos.parted
        modprobe zfs
        success "ZFS loaded."
    fi

    zpool version | head -1
}

# ─────────────────────────────────────────────────────────────────────
# Phase 2: Check and shrink ext4 filesystem
# ─────────────────────────────────────────────────────────────────────

phase2_shrink_ext4() {
    info "Phase 2: Shrinking ext4 filesystem"

    local part="/dev/nvme0n1p2"

    # Force fsck before resize (required by resize2fs).
    info "Running e2fsck on ext4 partition..."
    e2fsck -f "$part"
    success "Filesystem clean."

    # Shrink the filesystem.
    info "Shrinking ext4 filesystem to ${EXT4_SHRINK_SIZE}..."
    resize2fs "$part" "$EXT4_SHRINK_SIZE"
    success "Filesystem shrunk to ${EXT4_SHRINK_SIZE}."
}

# ─────────────────────────────────────────────────────────────────────
# Phase 3: Repartition the disk
# ─────────────────────────────────────────────────────────────────────

phase3_repartition() {
    info "Phase 3: Repartitioning the disk"
    info "This will:"
    info "  - Shrink partition 2 to 100GB (ext4 filesystem already shrunk)"
    info "  - Delete partition 3 (old swap)"
    info "  - Create partition 4 (ZFS, ~830GB)"

    # Use sfdisk to manipulate GPT partitions.
    # We need to delete p3, resize p2, and create p4.
    # sfdisk --dump gives us the current layout, we modify and apply.

    info "Backing up partition table..."
    sfdisk --dump /dev/nvme0n1 > /tmp/nvme-partitions-backup.txt
    cat /tmp/nvme-partitions-backup.txt

    # Apply new partition table using sfdisk script.
    info "Applying new partition layout..."
    sfdisk --no-reread /dev/nvme0n1 <<EOF
label: gpt

# p1: EFI system partition (unchanged)
/dev/nvme0n1p1 : start=4096, size=2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B

# p2: ext4 root — shrunk to 100GB
/dev/nvme0n1p2 : start=${EXT4_PART_START}, size=${EXT4_PART_SECTORS}, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4

# p3: (deleted — was swap)

# p4: ZFS rpool — fills remaining space
/dev/nvme0n1p4 : start=${ZFS_PART_START}, type=6A898CC3-1DD2-11B2-99A6-080020736631
EOF

    # Re-read partition table.
    partprobe /dev/nvme0n1
    sleep 2

    success "Partition table updated."
    fdisk -l /dev/nvme0n1
}

# ─────────────────────────────────────────────────────────────────────
# Phase 4: Create ZFS pool and datasets
# ─────────────────────────────────────────────────────────────────────

phase4_create_zfs() {
    info "Phase 4: Creating ZFS pool and datasets"

    local zfs_dev="${ZFS_PART}"

    # Wait for the partition device to appear.
    if [[ ! -e "$zfs_dev" ]]; then
        info "Waiting for partition device..."
        sleep 3
        if [[ ! -e "$zfs_dev" ]]; then
            # Fall back to raw device path.
            zfs_dev="/dev/nvme0n1p4"
            info "Using fallback device path: $zfs_dev"
        fi
    fi

    info "Creating ZFS pool '${POOL}' on ${zfs_dev}..."
    zpool create -f \
        -o ashift=12 \
        -o autotrim=on \
        -O acltype=posixacl \
        -O canmount=off \
        -O dnodesize=auto \
        -O normalization=formD \
        -O relatime=on \
        -O xattr=sa \
        -O compression=zstd \
        -O mountpoint=none \
        "${POOL}" \
        "$zfs_dev"

    success "Pool '${POOL}' created."

    # Create datasets with legacy mountpoints (managed by NixOS fstab).
    info "Creating datasets..."

    # Root dataset.
    zfs create -o canmount=noauto -o mountpoint=legacy "${POOL}/root"

    # Nix store — separate dataset for independent snapshot/compression control.
    zfs create -o mountpoint=legacy "${POOL}/nix"

    # Home — separate dataset for user data snapshots.
    zfs create -o mountpoint=legacy "${POOL}/home"

    success "Datasets created:"
    zfs list -r "${POOL}"
}

# ─────────────────────────────────────────────────────────────────────
# Phase 5: Mount filesystems and install NixOS
# ─────────────────────────────────────────────────────────────────────

phase5_install_nixos() {
    info "Phase 5: Mounting filesystems and installing NixOS"

    local MNT
    MNT=$(mktemp -d)

    info "Mount point: ${MNT}"

    # Mount root.
    zfs mount -o mountpoint="${MNT}" "${POOL}/root"

    # Mount nix.
    mkdir -p "${MNT}/nix"
    mount -t zfs "${POOL}/nix" "${MNT}/nix"

    # Mount home.
    mkdir -p "${MNT}/home"
    mount -t zfs "${POOL}/home" "${MNT}/home"

    # Mount EFI.
    mkdir -p "${MNT}/boot"
    mount "${EFI_PART}" "${MNT}/boot"

    success "All filesystems mounted."
    df -h "${MNT}" "${MNT}/nix" "${MNT}/home" "${MNT}/boot"

    # Copy entire home directory from old root to preserve auth state.
    # This carries over: Chrome sessions, 1Password, Discord, Steam,
    # gh tokens, keyrings, dotfiles, and all other user config.
    info "Copying home directories from old root..."
    if [[ -d /mnt/old-root/home ]]; then
        rsync -aHAX --info=progress2 /mnt/old-root/home/ "${MNT}/home/"
        success "Home directories copied (auth state preserved)."
    else
        warn "Old root not mounted at /mnt/old-root."
        warn "Falling back to dotfiles-only copy..."
        mkdir -p "${MNT}/home/jon"
        if [[ -d /mnt/old-root/home/jon/dotfiles ]]; then
            cp -a /mnt/old-root/home/jon/dotfiles "${MNT}/home/jon/dotfiles"
        else
            warn "Could not find dotfiles. You'll need to manually copy them."
            warn "Mount old ext4: mount /dev/nvme0n1p2 /mnt/old-root"
            warn "Then: rsync -aHAX /mnt/old-root/home/ ${MNT}/home/"
            read -rp "Press Enter once dotfiles are in place..." _
        fi
    fi

    # Also preserve Tailscale and PostgreSQL state from /var/lib.
    info "Copying system state (Tailscale, PostgreSQL)..."
    for svc in tailscale postgresql; do
        if [[ -d /mnt/old-root/var/lib/${svc} ]]; then
            mkdir -p "${MNT}/var/lib/${svc}"
            rsync -aHAX /mnt/old-root/var/lib/${svc}/ "${MNT}/var/lib/${svc}/"
            success "  Copied /var/lib/${svc}"
        fi
    done

    # Install NixOS.
    info "Running nixos-install..."
    info "Flake path: ${MNT}/home/jon/dotfiles#${FLAKE_CONFIG}"
    nixos-install --root "${MNT}" --flake "${MNT}/home/jon/dotfiles#${FLAKE_CONFIG}" --no-root-passwd

    success "NixOS installed!"

    # Clean up mounts.
    info "Unmounting..."
    umount "${MNT}/boot"
    umount "${MNT}/nix"
    umount "${MNT}/home"
    zfs unmount "${POOL}/root"

    info "Exporting pool..."
    zpool export "${POOL}"

    success "Migration complete!"
    echo ""
    info "┌─────────────────────────────────────────────────────────┐"
    info "│  Next steps:                                            │"
    info "│  1. Reboot and select NixOS (ZFS) from systemd-boot    │"
    info "│  2. Old ext4 system is still on partition 2             │"
    info "│  3. Once ZFS is stable, you can reclaim the 100GB      │"
    info "│  4. Set passwords: passwd jon                           │"
    info "└─────────────────────────────────────────────────────────┘"
}

# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       NixOS ext4 → ZFS Migration (Dual-Boot)            ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  Drive:  Samsung 970 EVO Plus 1TB                       ║${NC}"
    echo -e "${CYAN}║  Old:    100GB ext4 (fallback)                          ║${NC}"
    echo -e "${CYAN}║  New:    ~830GB ZFS rpool                               ║${NC}"
    echo -e "${CYAN}║  Swap:   None                                           ║${NC}"
    echo -e "${CYAN}║  Config: desktop-zfs                                    ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    phase0_preflight
    confirm "Phase 1: Install ZFS tools in the live environment?"
    phase1_install_zfs

    confirm "Phase 2: Shrink ext4 filesystem to ${EXT4_SHRINK_SIZE}? (Data safe — filesystem is 52GB, shrinking to 95GB)"
    phase2_shrink_ext4

    confirm "Phase 3: Repartition disk? (Shrink p2, delete swap p3, create ZFS p4)"
    phase3_repartition

    confirm "Phase 4: Create ZFS pool and datasets on the new partition?"
    phase4_create_zfs

    # Mount old root so we can copy dotfiles.
    info "Mounting old ext4 root for dotfiles access..."
    mkdir -p /mnt/old-root
    mount -o ro /dev/nvme0n1p2 /mnt/old-root
    success "Old root mounted at /mnt/old-root"

    confirm "Phase 5: Install NixOS on ZFS? (This runs nixos-install)"
    phase5_install_nixos

    # Clean up old root mount.
    umount /mnt/old-root 2>/dev/null || true

    echo ""
    success "All done! You can now reboot into your ZFS-based NixOS."
    echo -e "${GREEN}  sudo reboot${NC}"
}

main "$@"
