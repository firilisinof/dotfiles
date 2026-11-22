{ pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    # preserve the cluster's original collation
    initdbArgs = [
      "--encoding=UTF8"
      "--locale=C"
    ];
  };
}
