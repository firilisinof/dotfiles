{ pkgs }:

let
  app = pkgs.callPackage ./app.nix { };
in
{
  antigravity = app {
    pname = "antigravity-bin";
    version = "2.26.0";
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.26.0-6546645232517120/darwin-arm/Antigravity.zip";
    hash = "sha256-ImlYMml3n3dCL/6T+NVigEB13sYrWAC7M4q1nRw7Za0=";
    app = "Antigravity.app";
    archive = "zip";
    license = pkgs.lib.licenses.unfree;
  };
  beeper = app {
    pname = "beeper-bin";
    version = "4.3.229";
    url = "https://beeper-desktop.download.beeper.com/builds/Beeper-4.3.229-arm64-mac.zip";
    hash = "sha256-QsNl2NFUrftRpq5lxQ67QtFPEQklK/iZf+kCCJSYH44=";
    app = "Beeper Desktop.app";
    archive = "zip";
    license = pkgs.lib.licenses.unfree;
    commands = {
      beeper = "Contents/MacOS/Beeper Desktop";
    };
  };
  chatgpt = app {
    pname = "chatgpt-bin";
    version = "26.1021.31345";
    url = "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-darwin-arm64-26.1021.31345.zip";
    hash = "sha256-KvzVjgSEp2R5zKIxdOCFEnqdnmNGa3VznraCWl/2E/Q=";
    app = "ChatGPT.app";
    archive = "zip";
    license = pkgs.lib.licenses.unfree;
  };
  discord = app {
    pname = "discord-bin";
    version = "0.0.419";
    url = "https://dl.discordapp.net/apps/osx/0.0.419/Discord.dmg";
    hash = "sha256-8Zsx6va5fcHRblTZlDimN6XO3yKEH/9+KyfdF9TPjBI=";
    app = "Discord.app";
    archive = "dmg";
    license = pkgs.lib.licenses.unfree;
  };
  google-gemini = app {
    pname = "google-gemini-bin";
    version = "1.135.1.1291";
    url = "https://dl.google.com/release2/j33ro/release/Gemini.dmg";
    hash = "sha256-TMDepDOxM6NdXOks7JRPcGhI8vqkTvhp2e0PWGPOJf4=";
    app = "Gemini.app";
    archive = "dmg";
    license = pkgs.lib.licenses.unfree;
  };
  notion = app {
    pname = "notion-bin";
    version = "7.40.1";
    url = "https://desktop-release.notion-static.com/Notion-7.40.1-arm64.dmg";
    hash = "sha256-8yokHgVObDCMmJqMoP2kA6IPDqfKYlC/y4euPIhyq8o=";
    app = "Notion.app";
    archive = "dmg";
    license = pkgs.lib.licenses.unfree;
  };
  obs = app {
    pname = "obs-bin";
    version = "33.0.0";
    url = "https://cdn-fastly.obsproject.com/downloads/obs-studio-33.0.0-macos-apple.dmg";
    hash = "sha256-s29OnaXy8XxzO6cRyP4GVtawzVc8/pbus+aDJc/+9zk=";
    app = "OBS.app";
    archive = "dmg";
    license = pkgs.lib.licenses.gpl2Plus;
    commands = {
      obs = "Contents/MacOS/OBS";
    };
  };
  visual-studio-code = app {
    pname = "visual-studio-code-bin";
    version = "1.143.1";
    url = "https://update.code.visualstudio.com/1.143.1/darwin-arm64/stable";
    hash = "sha256-Zc7XAg6ZXCluEhiBsQzXukZjjOvF3eDLkhvILeE813I=";
    app = "Visual Studio Code.app";
    archive = "zip";
    license = pkgs.lib.licenses.unfree;
    commands = {
      code = "Contents/Resources/app/bin/code";
      code-tunnel = "Contents/Resources/app/bin/code-tunnel";
    };
  };
  zotero = app {
    pname = "zotero-bin";
    version = "10.0.6";
    url = "https://download.zotero.org/client/release/10.0.6/Zotero-10.0.6.dmg";
    hash = "sha256-uOQ/ShPMa70al5OAvt7dfrROdhHqJQH40fApP7yUcxw=";
    app = "Zotero.app";
    archive = "dmg";
    license = pkgs.lib.licenses.agpl3Only;
  };
}
