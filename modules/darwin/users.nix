{ ... }:

{
  nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.config.allowUnfree = true;

  system.primaryUser = "lucas";
  users.users.lucas.home = "/Users/lucas";
}
