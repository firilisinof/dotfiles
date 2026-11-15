{
  imports = [
    ./git
    ./gh
    ./zsh
    ./ssh
  ];
  xdg.enable = true;
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "zed_onelight";
      editor = {
        true-color = true;
        soft-wrap.enable = true;
        cursor-shape.insert = "bar";
      };
    };
  };
}
