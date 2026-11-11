# Dotfiles

Nix configuration for two hosts:

- `kanjiro`: Apple Silicon Mac with nix-darwin and Home Manager.
- `pi5`: Raspberry Pi 5 server with NixOS and Home Manager.

## Layout

| Path | Contents |
| --- | --- |
| `hosts/` | Settings for each host |
| `modules/common/` | Modules for both hosts |
| `modules/darwin/` | nix-darwin modules, all applied to `kanjiro` |
| `modules/server/` | NixOS service modules, all applied to `pi5` |
| `modules/home/lucas/` | Home Manager user modules |
| `modules/flake/` | Module exports, host configurations, formatter, and development shell |
| `secrets/` | One sops file for each host |

Each directory under `modules/<class>/` is one module. A service module declares its own site, backup, monitors, and secrets.

## Mac

1. Install [Determinate Nix](https://docs.determinate.systems) and [Homebrew](https://brew.sh), and sign in to the Mac App Store.
2. Put the sops age key in `~/.config/sops/age/keys.txt`.
3. Do the first activation:

   ```sh
   sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#kanjiro
   ```

After the first activation:

```sh
sudo darwin-rebuild switch --flake .#kanjiro
```

## Raspberry Pi

```sh
git -C ~/dotfiles pull --ff-only
nixos-rebuild switch --flake ~/dotfiles#pi5 --sudo
```

## Secrets

```sh
sops edit secrets/<host>.yaml
```

A new installation has a new SSH host key. Put its age key in `.sops.yaml`, then run `sops updatekeys secrets/<host>.yaml`:

```sh
ssh-keyscan -t ed25519 <host> | ssh-to-age
```

## Development

`nix develop`, or direnv, gives the shell with the secrets tools. Add new files to Git before a rebuild. Run `nix fmt` before a commit. CI runs the same check.
