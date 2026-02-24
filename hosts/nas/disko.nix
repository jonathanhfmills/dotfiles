# Declarative disk layout for NAS.
# Boot: Samsung 870 EVO 128GB (SATA)
# Root: Samsung 990 PRO 2TB (NVMe) — ZFS single-disk pool
#
# NOTE: A Samsung 980 PRO is also installed but has a firmware bug
# preventing initialization outside BIOS. Excluded until firmware
# is updated to 5B2QGXA7, then it can be added as a ZFS mirror.
{
  disko.devices = {
    disk = {
      boot = {
        device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_128GB_S5Y4R020S029736";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
            };
          };
        };
      };
      nvme0 = {
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7KHNJ0WC57731R";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          relatime = "on";
          normalization = "formD";
          mountpoint = "none";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options.mountpoint = "legacy";
            options."com.sun:auto-snapshot" = "false";
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
            options."com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
}
