{
  # the mainline device tree omits the cpu temperature sensor and the gpio fan
  hardware.deviceTree.overlays = [
    {
      name = "fan";
      dtsFile = ./fan.dtso;
      # a substring match that skips the ovl-rp1 variant, which adds rp1 at runtime and has no rp1_gpio label
      filter = "rpi-5-b.dtb";
    }
  ];
}
