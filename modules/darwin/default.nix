{ ... }:

{
  imports = [
    ./homebrew.nix
    ./nix.nix
    ./packages.nix
    ./users.nix
    ./security.nix
    ./system-defaults.nix
    ./keyboard.nix
    ./versioning.nix
    ./platform.nix
  ];
}
