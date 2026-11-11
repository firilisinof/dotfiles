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

Homebrew installs the Mac desktop apps that need `/Applications` or their own updates, and the Mac App Store apps through `mas`. Activation removes Homebrew packages that `modules/darwin/homebrew.nix` does not declare. Home Manager installs all other user software.

## Mac

1. Install [Determinate Nix](https://docs.determinate.systems) and [Homebrew](https://brew.sh), and sign in to the Mac App Store.
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

Use Apple Watch or your password for `sudo`, including when the Mac lid is closed. Enable your watch in System Settings > Touch ID & Password.

### Zotero MCP

The Mac Home Manager configuration installs the core `zotero-mcp` package from
the pinned upstream flake, without semantic search or optional PDF/EPUB extras.
After rebuilding:

1. In Zotero, enable **Settings → Advanced → Allow other applications on this
   computer to communicate with Zotero**.
2. Configure your MCP client to launch `/etc/profiles/per-user/lucas/bin/zotero-mcp`
   with arguments `serve --transport stdio` and environment variable
   `ZOTERO_LOCAL=true`. Keep Zotero running when using the server.
3. For local writes on Zotero 10+, run `ZOTERO_LOCAL=true zotero-mcp authorize-local`
   and approve the Zotero dialog. Older versions need Zotero Web API credentials
   for writes; local reads need no API key.

For clients using JSON MCP configuration:

```json
{
  "mcpServers": {
    "zotero": {
      "command": "/etc/profiles/per-user/lucas/bin/zotero-mcp",
      "args": ["serve", "--transport", "stdio"],
      "env": { "ZOTERO_LOCAL": "true" }
    }
  }
}
```

Restart the MCP client, then try searching your Zotero library.

### Obsidian skill commands

Home Manager installs `defuddle` for extracting web content, `knap` for rendering
Markdown templates, and an `obsidian` launcher for the Homebrew-installed app.
Knap uses the pinned npm distribution and its Day.js dependency, with Node.js
provided by Nix.

After rebuilding, open Obsidian and enable **Settings → General → Command line
interface**. Obsidian must be running for the CLI to connect. Check the commands
with `defuddle --help`, `knap --help`, and `obsidian help`.

## Raspberry Pi

Build and apply the configuration on the Pi:

```sh
git -C ~/dotfiles pull --ff-only
nixos-rebuild switch --flake ~/dotfiles#pi5 --sudo
```

Services are served only over Tailscale, except the hostnames in `dotfiles.tunnel.ingress`, which a Cloudflare tunnel publishes: Kanidm (`auth`) and the MCP shells.

### Remote MCP shell

`modules/nixos/mcp.nix` runs [stepbrobd's MCP shell](https://github.com/stepbrobd/inc/tree/master/pkgs/mcp) as `lucas`, so Claude and ChatGPT can run commands on the Pi, such as the Things CLI. Each app has its own Kanidm OAuth2 client, hostname and server instance, and every command is logged to `~/.local/state/mcp/<app>.log`. Codex and Claude Code on the Mac use SSH instead.

| App | Connector URL | OAuth client |
| --- | --- | --- |
| Claude | `https://claude.firilisinof.com/mcp` | `mcp-claude` and the secret `kanidm/mcp-claude-secret` |
| ChatGPT | `https://chatgpt.firilisinof.com/mcp` | `mcp-chatgpt` and the secret `kanidm/mcp-chatgpt-secret` |

Read a client secret with `sops decrypt --extract '["kanidm"]["mcp-claude-secret"]' secrets/pi5.yaml`.

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
