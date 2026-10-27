{ pkgs }:

[
  pkgs.autoconf
  pkgs.automake
  pkgs.bash
  pkgs.cmake
  pkgs.coreutils
  pkgs.fd
  pkgs.ffmpeg
  pkgs.findutils
  pkgs.getopt
  pkgs.gnumake
  pkgs.jq
  pkgs.libtool
  pkgs.meson
  pkgs.nasm
  pkgs.nixfmt
  pkgs.nodejs_22
  (pkgs.pkgconf.overrideAttrs (old: {
    installPhase = old.installPhase + ''
      ln -s pkgconf "$out/bin/pkg-config"
    '';
  }))
  pkgs.python314
  pkgs.ripgrep
  pkgs.rsync
  pkgs.rustup
  pkgs.typst
  pkgs.uv
  pkgs.wget
  pkgs.yt-dlp
]
