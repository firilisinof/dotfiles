{ ... }:

{
  environment.etc."sudoers.d/10-passwordless".text = ''
    lucas ALL=(ALL:ALL) NOPASSWD:SETENV: ALL
  '';

  security.pam.services.sudo_local.touchIdAuth = true;
}
