# Dotfiles

Personal configuration for Apple Silicon macOS. Requires [Homebrew](https://brew.sh).

```sh
./bin/install --all        # Install packages and config links
./bin/install             # Link configs only
./bin/install --packages  # Install Homebrew packages
./bin/install --dry-run   # Preview config links
```

Configs are in `config/`. Keep this repo in place and open a new terminal after
setup. The installer leaves existing files untouched if they conflict.

AI tools share `config/ai/bootstrap.md`, linked as the global instructions for
Codex, Claude Code, and Antigravity. It points to `~/Pessoal/ai-wiki`; keep that
wiki available locally and start a new session after changing instructions.
