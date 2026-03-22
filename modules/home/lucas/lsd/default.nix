{
  programs.lsd = {
    enable = true;
    settings = {
      icons.when = "auto";
      sorting.dir-grouping = "first";
      no-symlink = true;

      ignore-globs = [
        ".DS_Store"
        ".direnv"
        ".git"
      ];
    };
    colors = {
      user = 18;
      group = 23;
      size = {
        none = 238;
        small = 24;
        medium = 88;
        large = 52;
      };
    };
  };
}
