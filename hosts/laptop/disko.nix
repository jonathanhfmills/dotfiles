# Declarative disk layout for laptop.
# Boot + Root: WD PC SN730 512GB (NVMe) — ESP + ZFS single-disk pool
{
  disko.devices = {
    disk = {
      nvme0 = {
        device = "/dev/disk/by-id/nvme-WDC_PC_SN730_SDBQNTY-512G-1001_212198454503";
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
          "home/jon/Documents" = {
            type = "zfs_fs";
            mountpoint = "/home/jon/Documents";
            options.mountpoint = "legacy";
            options.recordsize = "128K";
            options."com.sun:auto-snapshot" = "true";
          };
          "home/jon/Pictures" = {
            type = "zfs_fs";
            mountpoint = "/home/jon/Pictures";
            options.mountpoint = "legacy";
            options.recordsize = "1M";
            options."com.sun:auto-snapshot" = "true";
          };
          "home/jon/Videos" = {
            type = "zfs_fs";
            mountpoint = "/home/jon/Videos";
            options.mountpoint = "legacy";
            options.recordsize = "1M";
            options."com.sun:auto-snapshot" = "true";
          };
          "home/jon/Music" = {
            type = "zfs_fs";
            mountpoint = "/home/jon/Music";
            options.mountpoint = "legacy";
            options.recordsize = "1M";
            options."com.sun:auto-snapshot" = "true";
          };
          activitywatch = {
            type = "zfs_fs";
            mountpoint = "/home/jon/.local/share/activitywatch";
            options.mountpoint = "legacy";
            options.recordsize = "4K";
            options.atime = "off";
            options."com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
}
