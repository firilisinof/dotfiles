# Dotfiles

This repository contains configuration for an Apple Silicon Mac and a Raspberry Pi NixOS server. The Mac uses nix-darwin. Both hosts use Home Manager.

## Apply the Mac configuration

The Mac requires Nix with flakes enabled, nix-darwin, and [Homebrew](https://brew.sh).

Run this command from the repository root:

```sh
sudo darwin-rebuild switch --flake .#kanjiro
```

Home Manager replaces managed files without backups. It manages Git, gh, Ghostty, Zsh, SSH, and skill links.

Edit user settings in `modules/home/lucas/`. Rebuild the configuration after each change. Add new files to Git before activation so the flake includes them. Open a new terminal after activation.

Keep the repository at `/Users/lucas/Pessoal/dotfiles` for the editable skill library. Changes to `config/ai/skills/` take effect without a rebuild.

## Files

| Path | Contents |
| --- | --- |
| `flake.nix` | Configuration entry points for both hosts |
| `hosts/kanjiro/` | Mac system settings |
| `hosts/pi5/` | Raspberry Pi system and hardware settings |
| `modules/home/lucas/default.nix` | Shared user profile for both hosts |
| `modules/home/lucas/darwin.nix` | macOS user settings and integrations |
| `modules/home/lucas/<package>/default.nix` | Settings for Git, gh, Ghostty, SSH, or Zsh |
| `modules/common/packages.nix` | Additional portable tools selected by the macOS profile |
| `modules/darwin/default.nix` | nix-darwin and Home Manager integration |
| `modules/darwin/homebrew.nix` | Homebrew dependencies |
| `config/` | Shared assets and skills |
| `config/ai/skills/<name>/SKILL.md` | Personal skills |
