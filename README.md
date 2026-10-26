# Dotfiles

This repository contains configuration for an Apple Silicon Mac and a Raspberry Pi NixOS server. The Mac uses nix-darwin and Home Manager.

## Apply the Mac configuration

The Mac requires Nix with flakes enabled, nix-darwin, and [Homebrew](https://brew.sh).

Run this command from the repository root:

```sh
sudo darwin-rebuild switch --flake .#kanjiro
```

Home Manager replaces managed files without backups. It manages Git, gh, Ghostty, Zsh, SSH, and skill links.

Edit the sources in `config/`. Rebuild the configuration after each change. Open a new terminal after activation.

Keep the repository in place for the editable skill library.

## Files

| Path | Contents |
| --- | --- |
| `modules/common/packages.nix` | Portable command-line tools |
| `modules/darwin/homebrew.nix` | Homebrew dependencies |
| `config/` | Application and shell configuration sources |
| `config/ai/skills/<name>/SKILL.md` | Personal skills |
