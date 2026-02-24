# Placeholder — replace with output of `nixos-generate-config --show-hardware-config`
# after first boot on actual NAS hardware.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "uas" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # NVIDIA RTX 3080 — safe to include before GPU is physically installed;
  # NixOS skips the driver if no NVIDIA hardware is detected.
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;  # RTX 3080 uses proprietary driver
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
}
