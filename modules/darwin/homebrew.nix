{ ... }:

{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
    # ghidra and REA registrations use this JDK's Homebrew path
    brews = [ "openjdk@21" ];
    casks = [ "mactex-no-gui" ];
  };
}
