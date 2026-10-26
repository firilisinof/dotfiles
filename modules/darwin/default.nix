{ ... }:

{
  imports = [ ./homebrew.nix ];
  # determinate owns the Nix daemon and its configuration
  nix.enable = false;
  programs.zsh.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
