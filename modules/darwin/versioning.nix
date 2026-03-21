{ config, ... }:

{
  system.configurationRevision = config.rev or config.dirtyRev or null;
  system.stateVersion = 6;
}
