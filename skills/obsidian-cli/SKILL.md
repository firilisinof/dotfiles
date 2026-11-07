---
name: obsidian-cli
description: Interact with Obsidian vaults using the Obsidian CLI to read, create, search, and manage notes, tasks, properties, and more. Also supports plugin and theme development with commands to reload plugins, run JavaScript, capture errors, take screenshots, and inspect the DOM. Use when the user asks to interact with their Obsidian vault, manage notes, search vault content, perform vault operations from the command line, or develop and debug Obsidian plugins and themes.
disable-model-invocation: true
license: MIT
---

# Obsidian CLI

Use the native CLI to interact with a running Obsidian instance. Requires Obsidian to be open.

## Select the executable

On macOS, use the CLI bundled with the installed application. The generic `obsidian` command may launch a different Nix-managed app version.

```bash
obsidian_cli=/Applications/Obsidian.app/Contents/MacOS/obsidian-cli
"$obsidian_cli" version
"$obsidian_cli" help
```

On other platforms, set `obsidian_cli` to the installed Obsidian CLI path. Keep this choice local to the shell session.

## Command reference

Run `"$obsidian_cli" help` and `"$obsidian_cli" help <command>` before using a command. Use flags supported by that installed version. Full docs: https://help.obsidian.md/cli

## Syntax

**Parameters** take a value with `=`. Quote values with spaces:

```bash
"$obsidian_cli" vault="$vault_name" create name="My Note" content="Hello world"
```

**Flags** are boolean switches with no value:

```bash
"$obsidian_cli" vault="$vault_name" create name="My Note" overwrite
```

For multiline content use `\n` for newline and `\t` for tab.

## File targeting

Many commands accept `file` or `path` to target a file. Without either, the active file is used.

- `file=<name>` — resolves like a wikilink (name only, no path or extension needed)
- `path=<path>` — exact path from vault root, e.g. `folder/note.md`

## Vault targeting

Always select the intended vault explicitly before editing. List registered vaults, then set `vault_name` to the requested vault. Use `vault=<name>` as the first parameter:

```bash
"$obsidian_cli" vaults verbose
vault_name="My Vault"
"$obsidian_cli" vault="$vault_name" search query="test"
```

## Common patterns

```bash
"$obsidian_cli" vault="$vault_name" read file="My Note"
"$obsidian_cli" vault="$vault_name" create name="New Note" content="# Hello" template="Template"
"$obsidian_cli" vault="$vault_name" append file="My Note" content="New line"
"$obsidian_cli" vault="$vault_name" search query="search term" limit=10
"$obsidian_cli" vault="$vault_name" daily:read
"$obsidian_cli" vault="$vault_name" daily:append content="- [ ] New task"
"$obsidian_cli" vault="$vault_name" property:set name="status" value="done" file="My Note"
"$obsidian_cli" vault="$vault_name" tasks daily todo
"$obsidian_cli" vault="$vault_name" tags sort=count counts
"$obsidian_cli" vault="$vault_name" backlinks file="My Note"
```

Use `total` on list commands to get a count. With Obsidian 1.15, `create` leaves a note closed unless `open` is supplied. Preserve the existing vault's folders and templates rather than copying example names into it.

## Plugin development

### Develop/test cycle

After making code changes to a plugin or theme, follow this workflow:

1. **Reload** the plugin to pick up changes:
   ```bash
   "$obsidian_cli" vault="$vault_name" plugin:reload id=my-plugin
   ```
2. **Check for errors** — if errors appear, fix and repeat from step 1:
   ```bash
   "$obsidian_cli" vault="$vault_name" dev:errors
   ```
3. **Verify visually** with a screenshot or DOM inspection:
   ```bash
   "$obsidian_cli" vault="$vault_name" dev:screenshot path=screenshot.png
   "$obsidian_cli" vault="$vault_name" dev:dom selector=".workspace-leaf" text
   ```
4. **Check console output** for warnings or unexpected logs:
   ```bash
   "$obsidian_cli" vault="$vault_name" dev:console level=error
   ```

### Additional developer commands

Run JavaScript in the app context:

```bash
"$obsidian_cli" vault="$vault_name" eval code="app.vault.getFiles().length"
```

Inspect CSS values:

```bash
"$obsidian_cli" vault="$vault_name" dev:css selector=".workspace-leaf" prop=background-color
```

Toggle mobile emulation:

```bash
"$obsidian_cli" vault="$vault_name" dev:mobile on
```

Run `"$obsidian_cli" help` to see additional developer commands including CDP and debugger controls.
