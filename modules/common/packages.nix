{ pkgs }:

[
  pkgs.agent-browser
  pkgs.antigravity-cli
  pkgs.autoconf
  pkgs.automake
  pkgs.bash
  pkgs.binutils
  pkgs.claude-code
  pkgs.cmake
  pkgs.codex
  pkgs.coreutils
  pkgs.e2fsprogs
  pkgs.fd
  pkgs.ffmpeg
  pkgs.findutils
  pkgs.gnumake
  pkgs.jq
  pkgs.libtool
  pkgs.meson
  pkgs.nasm
  pkgs.ninja
  pkgs.nixfmt
  pkgs.nodejs_22
  pkgs.omp
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
  pkgs.util-linux
  pkgs.uv
  pkgs.wget
  pkgs.yt-dlp
]
