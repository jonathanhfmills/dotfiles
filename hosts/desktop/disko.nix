# Declarative disk layout for desktop.
# Drive: Samsung SSD 970 EVO Plus 1TB
{
  disko.devices.disk.main = {
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4P4NG0M101390D";
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
