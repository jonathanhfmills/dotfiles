# Lenovo ThinkPad X1 Carbon Gen 9
# Intel 11th Gen (Tiger Lake), Thunderbolt 4, fingerprint reader, webcam.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "uas" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Intel CPU microcode + firmware.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # TrackPoint.
  hardware.trackpoint.enable = true;
  hardware.trackpoint.emulateWheel = true;

  # Fingerprint reader.
  services.fprintd.enable = true;

  # Power management (TLP for battery life).
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = true;
}
