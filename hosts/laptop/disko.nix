# Declarative disk layout for laptop.
# Drive: WD PC SN730 512GB NVMe
{
  disko.devices.disk.main = {
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
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
