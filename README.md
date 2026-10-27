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

Keep the repository at `/Users/lucas/Pessoal/dotfiles` for the editable skill library. Changes to `config/ai/skills/` take effect without a rebuild.

## Select AI tools per host

Kanjiro imports `modules/home/lucas/ai` in its Home Manager configuration. This module installs agent-browser, Antigravity CLI, Claude Code, Codex, and OMP, and links their shared skills. Pi5 does not import it.

To use these tools on another host, import the same module under `home-manager.users.lucas.imports`. Set `home-manager.extraSpecialArgs.dotfilesDirectory` to the local repository path. The host must allow the unfree packages `antigravity-cli` and `claude-code` in its Nixpkgs configuration. Configure a browser for agent-browser on that host. Kanjiro uses its Home Manager Chrome app.

## Files

| Path | Contents |
| --- | --- |
| `flake.nix` | Configuration entry points for both hosts |
| `hosts/kanjiro/` | Mac system settings |
| `hosts/pi5/` | Raspberry Pi system and hardware settings |
| `modules/home/lucas/default.nix` | Shared user profile for both hosts |
| `modules/home/lucas/darwin.nix` | macOS user settings and integrations |
| `modules/home/lucas/ai/default.nix` | Optional AI tools and shared skill links |
| `modules/home/lucas/<package>/default.nix` | Settings for Git, gh, Ghostty, SSH, or Zsh |
| `modules/common/packages.nix` | Additional portable tools selected by the macOS profile |
| `modules/darwin/default.nix` | nix-darwin and Home Manager integration |
| `modules/darwin/homebrew.nix` | Homebrew dependencies |
| `config/` | Shared assets and skills |
| `config/ai/skills/<name>/SKILL.md` | Personal skills |
