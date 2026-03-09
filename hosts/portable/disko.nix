# Declarative disk layout for portable.
# Drive: SanDisk 3.2Gen1 128GB (USB)
{
  disko.devices.disk.main = {
    device = "/dev/disk/by-id/usb-USB_SanDisk_3.2Gen1_03023426120425182502-0:0";
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
            mountOptions = [ "defaults" "noatime" "discard" ];
          };
        };
      };
    };
  };
}
