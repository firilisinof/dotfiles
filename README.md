# Dotfiles

Nix configuration for two hosts:

- `kanjiro`: Apple Silicon Mac with nix-darwin and Home Manager.
- `pi5`: Raspberry Pi 5 with NixOS and Home Manager.

## Layout

| Path | Contents |
| --- | --- |
| `hosts/` | Settings for each host |
| `modules/common/` | Modules for nix-darwin and NixOS |
| `modules/darwin/` | nix-darwin modules |
| `modules/nixos/` | NixOS service modules |
| `modules/home/lucas/` | Home Manager user modules |
| `modules/flake/` | Module exports and host configurations |
| `secrets/` | Secrets encrypted with sops |
| `skills/` | AI agent skills |
| `wallpapers/` | Wallpapers |

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

## Raspberry Pi

Build and apply the configuration on the Pi:

```sh
git -C ~/dotfiles pull --ff-only
nixos-rebuild switch --flake ~/dotfiles#pi5 --sudo
```

For a new installation, the host SSH key changes. Add the new key to `.sops.yaml` and run `sops updatekeys` on the secrets file of the host.

## Secrets

```sh
sops edit secrets/<host>.yaml
```
