{ ... }:

{
  system.keyboard = {
    enableKeyMapping = true;
    # Remap §± to ~
    userKeyMapping = [
      {
        HIDKeyboardModifierMappingDst = 30064771125;
        HIDKeyboardModifierMappingSrc = 30064771172;
      }
    ];
  };
}
