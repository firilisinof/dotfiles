{ inputs, ... }:

{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem.treefmt = {
    projectRootFile = "flake.nix";
    programs = {
      actionlint.enable = true;
      deadnix.enable = true;
      nixfmt.enable = true;
      ruff-check.enable = true;
      ruff-format.enable = true;
      statix = {
        enable = true;
        # one key per concern reads better than one nested set per module
        disabled-lints = [ "repeated_keys" ];
      };
      taplo.enable = true;
      yamlfmt = {
        enable = true;
        settings.formatter.retain_line_breaks_single = true;
      };
    };
    # sops owns the layout of its files
    settings.global.excludes = [ "secrets/*" ];
  };
}
