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

Personal skills live in `config/ai/skills/<name>/SKILL.md`. Include `name`, `description`, and `disable-model-invocation: true` in YAML frontmatter. For Codex, add `agents/openai.yaml`:

```yaml
policy:
  allow_implicit_invocation: false
```

The installer links the skill library to:

- Codex: `~/.agents/skills`
- Claude Code: `~/.claude/skills`
- Oh My Pi: `~/.omp/agent/skills`

Claude Code uses `"user-invocable-only"` skill overrides. Codex uses `[skills] include_instructions = false` to omit the skill catalog while retaining explicit skill mentions. Oh My Pi keeps discovery and skill commands enabled with `skillful: false` to omit its catalog. General skill-use policy lives in the [wiki instructions](../ai-wiki/instructions.md).

Builtin prompt-skill plugins `cc-plugin-plugin-authoring@builtin` and `cc-plugin-claude-test@builtin` are opt-in through Claude's `enabledPlugins` settings. Their installed assets remain available, but their native commands require explicit re-enabling. Claude Test's bundled browser-test tools are opt-in with that plugin.

Antigravity does not receive a discovery link to this library because its documented skill discovery loads names and descriptions automatically. Request a skill by its file path instead, for example: `Use the simplify skill at ~/Pessoal/dotfiles/config/ai/skills/simplify/SKILL.md for this task.` This preserves access without preloading the personal library. Antigravity's bundled skills are separate from this library.

The installed Antigravity App/CLI setting `userSettings.disableDefaultCustomizations: true` disables shipped default customizations. This is an installed-code-backed setting with a feature-gated UI, not a verified native Knowledge opt-out. See the [wiki integration notes](../ai-wiki/memory/dotfiles/ai-harness-integration.md) for version-specific evidence and limits.

Add or edit personal skills here without reinstalling. Downloaded `synced/` files are managed by Claude, not edited here. Keep rules and project memory in `~/Pessoal/ai-wiki`, not in native harness memory stores.

Humanizer v3.0.0 is vendored in `config/ai/skills/humanizer/` with its MIT license,
from [akitaonrails/my-skills](https://github.com/akitaonrails/my-skills/tree/7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a/humanizer)
at revision `7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a`.
Local metadata makes invocation manual-only in Codex (`$humanizer`), Claude Code
(`/humanizer`), and Oh My Pi (`/skill:humanizer`). Codex needs
`agents/openai.yaml` for this policy.

Simplify is vendored in `config/ai/skills/simplify/SKILL.md` from
[akitaonrails/my-skills](https://github.com/akitaonrails/my-skills/blob/7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a/simplify/SKILL.md)
at revision `7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a`, with local manual-only
metadata. Invoke explicitly with `$simplify` in Codex, `/simplify` in Claude Code, or `/skill:simplify` in Oh My Pi. In Antigravity, use the explicit file-path request described above.

Agent Browser is vendored in `config/ai/skills/agent-browser/SKILL.md` from
[akitaonrails/my-skills](https://github.com/akitaonrails/my-skills/blob/7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a/agent-browser/SKILL.md)
at revision `7b8a5e5e0259da8cabcdaf806cca9d1d55abf20a`. The upstream
`hidden: true` flag is removed locally to enable discovery, and manual-only
metadata is added. Invoke with `$agent-browser` in Codex, `/agent-browser` in Claude Code, or `/skill:agent-browser` in Oh My Pi. In Antigravity, request `config/ai/skills/agent-browser/SKILL.md` by its full path.
The skill requires the separate CLI and browser installation:

```sh
npm install -g agent-browser
agent-browser install
```

Read `agent-browser skills get core` before using it. The CLI supplies workflows
that match its installed version.

Montar Apresentacao (`montar-apresentacao`) and Reconcile BEPE Ledger (`reconcile-bepe-ledger`) are personal skills with the same manual-only metadata. Invoke them with `$montar-apresentacao` or `$reconcile-bepe-ledger` in Codex, `/montar-apresentacao` or `/reconcile-bepe-ledger` in Claude Code, or `/skill:montar-apresentacao` or `/skill:reconcile-bepe-ledger` in Oh My Pi. In Antigravity, request the corresponding `config/ai/skills/<name>/SKILL.md` by its full path.

Oh My Pi needs discovery and commands enabled without the automatic skill catalog:

```sh
omp config set skills.enabled true
omp config set skills.enableSkillCommands true
omp config set skillful false
```

Start new harness sessions after configuration changes. Existing sessions can retain earlier context.

## Ghidra

`Brewfile` includes OpenJDK 21. The REA-compatible Ghidra installation is managed separately at `~/Applications/ghidra_12.1.4_PUBLIC`. Launch its GUI with:

```sh
~/Applications/ghidra_12.1.4_PUBLIC/ghidraRun
```

That installation's `support/launch.properties` selects `/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home` through `JAVA_HOME_OVERRIDE`, without changing the shell's default Java runtime. REA's Claude Code, Codex, Antigravity, and OMP registrations use that same JDK and installation directory. Select the `ghidra` provider explicitly when an investigation should use it rather than Hopper.

Installation compatibility and native-build details are in the [Ghidra configuration note](../ai-wiki/memory/dotfiles/ghidra.md).
