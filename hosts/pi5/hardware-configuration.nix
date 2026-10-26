{ ... }:

{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/92d8dd22-ae8e-4451-999f-73ce08ef248f";
    fsType = "ext4";
    options = [ "noatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
    options = [ "noatime" ];
  };
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-uuid/2178-694E";
    fsType = "vfat";
    options = [
      "noauto"
      "nofail"
    ];
  };
}
