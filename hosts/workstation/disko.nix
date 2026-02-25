# Declarative disk layout for workstation.
# Pool + Boot: 2x Samsung 980 Pro OEM 1TB (NVMe) — ZFS mirror + mirrored ESP
#
{
  disko.devices = {
    disk = {
      nvme0 = {
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00A00_S6H6NA0W700362";
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
      nvme1 = {
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00A00_S6H6NA0W700375";
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
                mountpoint = "/boot-fallback";
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
        mode = "mirror";
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
          games = {
            type = "zfs_fs";
            mountpoint = "/home/jon/.local/share/Steam/steamapps";
            options.mountpoint = "legacy";
            options.recordsize = "1M";
            options.compression = "lz4";
            options.atime = "off";
          };
          postgres = {
            type = "zfs_fs";
            mountpoint = "/var/lib/postgresql";
            options.mountpoint = "legacy";
            options.recordsize = "16K";
            options.logbias = "throughput";
            options.atime = "off";
            options."com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
}
