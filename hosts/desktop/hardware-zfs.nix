# ZFS-based hardware configuration for desktop.
# Drive: Samsung SSD 990 PRO 2TB (moved from workstation)
# By-ID: nvme-Samsung_SSD_990_PRO_2TB_S7KHNJ0WC57731R
# Use with: nixos-rebuild switch --flake .#desktop-zfs
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "uas" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # ZFS support.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # ZFS requires a unique hostId (8 hex chars).
  networking.hostId = "726f84c0";

  # LTS kernel — required for out-of-tree ZFS module compatibility.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  # Disable disko-generated fileSystems from default.nix (ext4 layout).
  disko.enableConfig = false;

  # ZFS root pool on 990 PRO 2TB (imported from workstation — same dataset layout).
  fileSystems."/" = {
    device = "rpool/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "rpool/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "rpool/home";
    fsType = "zfs";
  };

  fileSystems."/home/jon/.local/share/activitywatch" = {
    device = "rpool/activitywatch";
    fsType = "zfs";
  };

  # EFI system partition on 990 PRO
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/C240-4F35";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # No swap — 16GB RAM is sufficient for desktop workloads.
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
