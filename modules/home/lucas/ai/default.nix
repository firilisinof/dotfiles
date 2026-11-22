{ lib, pkgs, ... }:

let
  # Claude and Codex store their explicit-invocation policies in different files
  claudeSkills = pkgs.runCommand "claude-wiki-skills" { } ''
    cp -R ${../../../../skills} "$out"
    chmod -R u+w "$out"
    for skill in "$out"/*/SKILL.md; do
      sed -i '2i disable-model-invocation: true' "$skill"
    done
  '';
in
{
  imports = [ ./wiki.nix ];

  home.packages = [
    pkgs.antigravity-cli
    pkgs.claude-code
    pkgs.codex
    pkgs.codex-login
  ];

  # every harness loads the same user-level instructions
  home.file = {
    ".agents/skills/wiki".source = ../../../../skills/wiki;
    ".agents/skills/project-plan".source = ../../../../skills/project-plan;
    ".claude/skills/wiki".source = "${claudeSkills}/wiki";
    ".claude/skills/project-plan".source = "${claudeSkills}/project-plan";
    ".claude/CLAUDE.md".source = ./context.md;
    ".codex/AGENTS.md".source = ./context.md;
    ".gemini/GEMINI.md".source = ./context.md;
  };

  # each client keeps ownership of its other settings
  home.activation.wikiSessionHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.python3} ${./install-hooks.py} ${./session-hook.json} \
      "$HOME/.claude/settings.json" "''${CODEX_HOME:-$HOME/.codex}/hooks.json"
  '';
}
