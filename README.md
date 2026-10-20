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

Personal skills live in `config/ai/skills/<name>/SKILL.md`. Include `name`,
`description`, and `disable-model-invocation: true` in YAML frontmatter, followed
by Markdown instructions. For Codex, also add `agents/openai.yaml`:

```yaml
policy:
  allow_implicit_invocation: false
```

These controls keep skills user-invoked in Claude Code, Codex, and Oh My Pi.
The shared bootstrap also requests explicit user invocation for all skills.
Antigravity has no documented manual-only control, so this is best-effort there.
Claude Code's built-in and synced skills use name-based `skillOverrides` set to
`"user-invocable-only"` in `~/.claude/settings.json`. Those overrides do not apply
to plugin skills. Downloaded `synced/` files are managed by Claude, not edited here.
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
`agents/openai.yaml` for this policy.

Simplify is vendored in `config/ai/skills/simplify/SKILL.md` from
[akitaonrails/my-skills](https://github.com/akitaonrails/my-skills/blob/7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a/simplify/SKILL.md)
at revision `7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a`, with local manual-only
metadata. Invoke explicitly with `$simplify` in Codex, `/simplify` in Claude Code
or Antigravity, or `/skill:simplify` in Oh My Pi.

Agent Browser is vendored in `config/ai/skills/agent-browser/SKILL.md` from
[akitaonrails/my-skills](https://github.com/akitaonrails/my-skills/blob/7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a/agent-browser/SKILL.md)
at revision `7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a`. The upstream
`hidden: true` flag is removed locally to enable discovery, and manual-only
metadata is added. Invoke with
`$agent-browser` in Codex, `/agent-browser` in Claude Code or Antigravity,
or `/skill:agent-browser` in Oh My Pi.
The skill requires the separate CLI and browser installation:

```sh
npm install -g agent-browser
agent-browser install
```

Read `agent-browser skills get core` before using it. The CLI supplies workflows
that match its installed version.

Oh My Pi needs discovery and commands enabled. Manual-only skill metadata hides
these skills from automatic selection even when `skillful` is enabled:

```sh
omp config set skills.enabled true
omp config set skills.enableSkillCommands true
omp config set skillful true
```

Start a new session after changing these settings.
