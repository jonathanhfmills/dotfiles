# ZFS-based hardware configuration for desktop.
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

  # Override kernel to default LTS — the desktop config sets linuxPackages_latest
  # which may be too new for the out-of-tree ZFS module.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  # ZFS root pool datasets (legacy mountpoints managed by NixOS).
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

  # Shared EFI system partition (same as ext4 config).
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3C74-67BA";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # No swap — 16GB RAM is sufficient for desktop workloads.
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
