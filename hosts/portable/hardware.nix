{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # Broad module support for portability across ANY machine.
  boot.initrd.availableKernelModules = [
    # Storage
    "ahci" "nvme" "usbhid" "sd_mod" "sr_mod"
    "ehci_pci" "ohci_pci" "sdhci_pci"
    # Ethernet (Intel, Realtek, Broadcom — covers most desktops/laptops)
    "e1000e" "igb" "igc" "ixgbe"
    "r8169" "r8152"
    "tg3" "bnxt_en"
    # Virtio (VMs)
    "virtio_net" "virtio_blk" "virtio_pci"
  ];
  # USB modules loaded immediately so the drive is ready before ZFS import.
  boot.initrd.kernelModules = [ "xhci_pci" "usb_storage" "uas" ];
  boot.kernelModules = [
    "kvm-intel" "kvm-amd"
    # USB ethernet/WiFi adapters (plug in any adapter and it just works)
    "cdc_ether" "rndis_host" "ax88179_178a"
  ];
  boot.extraModulePackages = [ ];

  # WiFi + Bluetooth firmware for all common chipsets.
  hardware.enableAllFirmware = true;
  networking.wireless.enable = false;  # Let NetworkManager handle WiFi

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
