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

Homebrew installs the vendor desktop apps in `/Applications`: Antigravity, Beeper, ChatGPT, Claude, Discord, Gemini, Notion, OBS, Visual Studio Code, and Zotero. These apps update themselves. Homebrew does not update or upgrade them during activation. The Visual Studio Code cask adds the `code` and `code-tunnel` commands.

Homebrew also retains MacTeX, Steam, Tailscale, Mullvad, and VLC. Claude Code looks for the Claude app only at `/Applications/Claude.app`. MacTeX supplies TeX Live 2026. Steam manages its client updates and helpers. The VPN installers manage privileged system components. VLC requires signature metadata that the Nix store does not preserve.

Home Manager installs Anki, Firefox, Google Chrome, and Obsidian from Nixpkgs. Open them from `~/Applications/Home Manager Apps/`.

The Java 21 installation for Ghidra is available at `~/.local/share/java/jdk21`.

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
| `modules/home/lucas/<package>/default.nix` | Settings for Git, gh, Ghostty, SSH, or Zsh |
| `skills/<name>/SKILL.md` | Personal skills |
| `wallpapers/` | Wallpapers and their source credits |
