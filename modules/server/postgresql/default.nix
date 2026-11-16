{ pkgs, ... }:

{
  # one instance for every service, on the major version Securo's image uses
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    # both container databases were created with the C collation
    initdbArgs = [
      "--encoding=UTF8"
      "--locale=C"
    ];
  };
}
