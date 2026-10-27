# Dotfiles

This repository contains configuration for an Apple Silicon Mac and a Raspberry Pi NixOS server. The Mac uses nix-darwin. Both hosts use Home Manager.

## Apply the Mac configuration

The Mac requires Nix with flakes enabled, nix-darwin, and [Homebrew](https://brew.sh).

Run this command from the repository root:

```sh
sudo darwin-rebuild switch --flake .#kanjiro
```

Home Manager manages Git, gh, Ghostty, Zsh, SSH, and skill links. If activation reports a conflicting unmanaged file, delete that file and run the command again. No backup is required.

Edit user settings in `modules/home/lucas/`. Rebuild the configuration after each change. Add new files to Git before activation so the flake includes them. Open a new terminal after activation.

Each file or directory in `modules/common/`, `modules/darwin/`, and `modules/home/lucas/` is a module. The flake exports each module by its name. Home modules apply macOS settings and packages only on macOS, so you can import them on Linux and macOS hosts.

Keep the repository at `/Users/lucas/Pessoal/dotfiles` for the editable skill library. Changes to `skills/` take effect without a rebuild.

## Select AI tools per host

Kanjiro imports `homeModules.lucas.ai` in `modules/flake/configurations.nix`. This module installs Antigravity CLI, Claude Code, Codex, and OMP, and links their shared skills. Pi5 does not import it.

To use these tools on another host, add the same module to that host's `home-manager.users.lucas.imports`. Set `home-manager.users.lucas.dotfiles.directory` to the local repository path. The host must allow the unfree packages `antigravity-cli` and `claude-code` in its Nixpkgs configuration.

## macOS packages

Open managed apps from `~/Applications/Home Manager Apps/`. Versioned vendor downloads are declared in `pkgs/darwin/default.nix`. The shared package function preserves their signed bundles. To update an app, change its version, download URL, and SHA-256 hash together. Build the Mac configuration and verify the app signature before activation. App updates made inside a copied bundle can be replaced by a later Home Manager activation.

Gemini uses a download URL that can change. Its checksum is pinned. If the vendor replaces that download, update the version and checksum after verification.

Homebrew retains Claude, MacTeX, Steam, Tailscale, Mullvad, and VLC. Claude Code looks for the Claude app only at `/Applications/Claude.app`. MacTeX supplies TeX Live 2026. Steam manages its client updates and helpers. The VPN installers manage privileged system components. VLC requires signature metadata that the Nix store does not preserve.

Ollama uses a Home Manager launch agent. Its models remain in `~/.ollama`, and its log is `~/Library/Logs/ollama.log`. The Java 21 installation for Ghidra is available at `~/.local/share/java/jdk21`.

## Files

| Path | Contents |
| --- | --- |
| `flake.nix` | Inputs, and the autopilot entry point that loads every file in `modules/flake/` as a flake-parts module |
| `modules/flake/configurations.nix` | Modules and Home Manager profiles that each host imports |
| `modules/flake/modules.nix` | Exports `darwinModules`, `nixosModules`, and `homeModules.lucas` from the module directories |
| `hosts/kanjiro/` | Mac system settings |
| `hosts/pi5/` | Raspberry Pi system and hardware settings |
| `modules/common/` | Modules for both nix-darwin and NixOS, such as binary caches and Home Manager integration |
| `modules/darwin/` | nix-darwin system settings and Homebrew dependencies |
| `modules/home/lucas/default.nix` | Shared user profile for both hosts |
| `modules/home/lucas/darwin.nix` | macOS user settings and integrations |
| `modules/home/lucas/ai/default.nix` | Optional AI tools and shared skill links |
| `modules/home/lucas/packages/default.nix` | Additional portable tools selected by the macOS profile |
| `modules/home/lucas/<package>/default.nix` | Settings for Git, gh, Ghostty, Ollama, SSH, or Zsh |
| `pkgs/darwin/` | Pinned macOS vendor packages |
| `skills/<name>/SKILL.md` | Personal skills |
| `wallpapers/` | Wallpapers and their source credits |
