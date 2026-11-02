# Dotfiles

Nix configuration for two hosts:

- `kanjiro`: Apple Silicon Mac with nix-darwin and Home Manager.
- `pi5`: Raspberry Pi 5 with NixOS and Home Manager.

## Layout

| Path | Contents |
| --- | --- |
| `hosts/` | Settings for each host |
| `modules/common/` | Modules for nix-darwin and NixOS |
| `modules/darwin/` | nix-darwin modules, all applied to `kanjiro` |
| `modules/nixos/` | NixOS service modules, all applied to `pi5` |
| `modules/home/lucas/` | Home Manager user modules |
| `modules/flake/` | Module exports, host configurations, and the formatter |
| `secrets/` | Secrets encrypted with sops |
| `skills/` | AI agent skills |
| `wallpapers/` | Wallpapers |

Every file or directory under `modules/<class>/` is one module named after it. A service module keeps its helper scripts next to its `default.nix` and declares its own Caddy site, backup paths, and secrets.

Homebrew installs the Mac desktop apps that need `/Applications` or their own updates. Home Manager installs all other user software.

## Mac

1. Install [Determinate Nix](https://docs.determinate.systems) and [Homebrew](https://brew.sh).
2. Clone the repository to `~/Pessoal/dotfiles`.
3. Put the sops age key in `~/.config/sops/age/keys.txt`.
4. Do the first activation:

   ```sh
   sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#kanjiro
   ```

After the first activation, use this command:

```sh
sudo darwin-rebuild switch --flake .#kanjiro
```

Add new files to Git before you rebuild.

Use Touch ID or your password for `sudo`. The built-in Touch ID sensor requires the Mac lid to be open.

## Raspberry Pi

Build and apply the configuration on the Pi:

```sh
git -C ~/dotfiles pull --ff-only
nixos-rebuild switch --flake ~/dotfiles#pi5 --sudo
```

For a new installation, the host SSH key changes. Add the new key to `.sops.yaml` and run `sops updatekeys` on the secrets file of the host.

## Secrets

Run this command in the development shell:

```sh
sops edit secrets/<host>.yaml
```

## Development

Enter the shell with the secrets tools, or let direnv do it:

```sh
nix develop
```

Format and lint every file before committing. CI runs the same check.

```sh
nix fmt
```
