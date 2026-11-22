{ lib, pkgs, ... }:

let
  skills = ../../../../skills;
  skillNames = builtins.attrNames (
    lib.filterAttrs (
      name: kind: kind == "directory" && builtins.pathExists (skills + "/${name}/SKILL.md")
    ) (builtins.readDir skills)
  );

  # mirror each skill's Codex invocation policy in Claude's frontmatter
  claudeSkills = pkgs.runCommand "claude-workflow-skills" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
    cp -R ${skills} "$out"
    chmod -R u+w "$out"
    for skill in "$out"/*/SKILL.md; do
      policy="$(dirname "$skill")/agents/openai.yaml"
      if [ -f "$policy" ]; then
        implicit=$(yq -r '.policy.allow_implicit_invocation' "$policy")
        if [ "$implicit" = false ]; then
          sed -i '2i disable-model-invocation: true' "$skill"
        fi
      fi
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

  home.file =
    lib.listToAttrs (
      lib.concatMap (name: [
        (lib.nameValuePair ".agents/skills/${name}" { source = skills + "/${name}"; })
        (lib.nameValuePair ".claude/skills/${name}" { source = "${claudeSkills}/${name}"; })
      ]) skillNames
    )
    // {
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
