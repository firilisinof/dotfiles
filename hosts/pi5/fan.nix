{ lib, ... }:

let
  # the cpu idles near 60 c in the case, so the fan stays off until 70 c and stops again below 65 c
  # each trip runs the fan at its vendor cooling level: 75, 125, 175 and 250 of 255
  curve = {
    cpu_tepid = 70000;
    cpu_warm = 73000;
    cpu_hot = 76000;
    cpu_vhot = 80000;
  };
in
{
  hardware.deviceTree.overlays = [
    {
      name = "fan";
      # a substring match on the pi 5 model b device trees, including the d0 one that u-boot loads
      filter = "rpi-5-b.dtb";
      # u-boot passes the vendor device tree without the firmware's fixups, which enable these nodes
      dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "brcm,bcm2712";
        };

        // the nvme drive is on the external pcie connector
        &pciex1 {
          status = "okay";
        };

        &rp1_pwm1 {
          status = "okay";
        };

        &fan {
          status = "okay";
        };

        ${lib.concatStrings (
          lib.mapAttrsToList (trip: temperature: ''
            &${trip} {
              temperature = <${toString temperature}>;
            };
          '') curve
        )}
      '';
    }
  ];
}
