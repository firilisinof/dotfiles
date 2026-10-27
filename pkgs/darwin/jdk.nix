{ temurin-bin-21, fetchurl }:
temurin-bin-21.overrideAttrs {
  version = "21.0.13";
  src = fetchurl {
    url = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.13_9.tar.gz";
    hash = "sha256-vwNrNbBxv7L1TywK+O6NiK+pXubrPc4CwPlM/CUk0Eo=";
  };
  dontFixup = true;
}
