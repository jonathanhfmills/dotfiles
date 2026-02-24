{ config, lib, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # Broad module support for portability across machines.
  boot.initrd.availableKernelModules = [
    "ahci" "nvme" "usbhid" "sd_mod"
    "ehci_pci" "ohci_pci" "sdhci_pci"
  ];
  # USB modules loaded immediately so the drive is ready before ZFS import.
  boot.initrd.kernelModules = [ "xhci_pci" "usb_storage" "uas" ];
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
