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

`config/ai/bootstrap.md` is shared by Codex, Claude Code, Gemini, and omp.

Personal skills live in `config/ai/skills/<name>/SKILL.md`. Include `name` and
`description` in YAML frontmatter, followed by Markdown instructions.
The installer links the shared skills directory to:

- Codex: `~/.agents/skills`
- Claude Code: `~/.claude/skills`
- Antigravity IDE/App: `~/.gemini/config/skills`
- Oh My Pi: `~/.omp/agent/skills`

Add or edit skills in this repo; the links reflect changes without reinstalling.
Keep shared skills portable and rules and project memory in `~/Pessoal/ai-wiki`.
Antigravity skill discovery through the link still needs verification in the app.

Humanizer v3.0.0 is vendored in `config/ai/skills/humanizer/` with its MIT license,
from [akitaonrails/my-skills](https://github.com/akitaonrails/my-skills/tree/7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a/humanizer)
at revision `7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a`.
Local metadata makes invocation manual-only in Codex (`$humanizer`), Claude Code
(`/humanizer`), and Oh My Pi (`/skill:humanizer`). Codex needs
`agents/openai.yaml` for this policy. Antigravity supports `/humanizer`, but its
docs do not specify a manual-only setting, so the description requests explicit
invocation there without guaranteeing enforcement.
