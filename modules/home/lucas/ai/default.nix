{
  config,
  pkgs,
  dotfilesDirectory,
  ...
}:

let
  skills = config.lib.file.mkOutOfStoreSymlink "${dotfilesDirectory}/config/ai/skills";
in
{
  home.packages = [
    pkgs.agent-browser
    pkgs.antigravity-cli
    pkgs.claude-code
    pkgs.codex
    pkgs.omp
  ];

  home.file = {
    ".agents/skills".source = skills;
    ".claude/skills".source = skills;
    ".omp/agent/skills".source = skills;
  };
}
