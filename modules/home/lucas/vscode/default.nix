{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;

    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;

      extensions = with pkgs.vscode-extensions; [
        b4dm4n.vscode-nixpkgs-fmt
        jnoortheen.nix-ide
        charliermarsh.ruff
        dbaeumer.vscode-eslint
        dotjoshjohnson.xml
        github.vscode-github-actions
        github.vscode-pull-request-github
        james-yu.latex-workshop
        llvm-vs-code-extensions.vscode-clangd
        mechatroner.rainbow-csv
        mkhl.direnv
        ms-azuretools.vscode-docker
        ms-python.isort
        ms-python.python
        ms-python.vscode-pylance
        ms-toolsai.jupyter
        ms-toolsai.jupyter-renderers
        ms-toolsai.vscode-jupyter-cell-tags
        ms-toolsai.vscode-jupyter-slideshow
        ms-vscode-remote.remote-containers
        ms-vscode-remote.remote-ssh
        ms-vscode.cmake-tools
        myriad-dreamin.tinymist
        anthropic.claude-code
        redhat.vscode-yaml
        shd101wyy.markdown-preview-enhanced
        tamasfe.even-better-toml
        tomoki1207.pdf
        vscode-icons-team.vscode-icons
        (pkgs.vscode-utils.extensionFromVscodeMarketplace {
          name = "chatgpt";
          publisher = "openai";
          version = "26.5323.20928";
          sha256 = "0malac6ycpz6zsaqxx1ay8vp9nx7k0ziyzmyxk1b47hgq50dlrc1";
        })
        yzhang.markdown-all-in-one
      ];

      userSettings = {
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";
        "extensions.autoCheckUpdates" = false;
        "window.titleBarStyle" = "custom";
        "cmake.ignoreCMakeListsMissing" = true;
        "workbench.startupEditor" = "none";
        "workbench.colorTheme" = "Default Light Modern";
        "workbench.iconTheme" = "vscode-icons";
        "workbench.editorAssociations" = {
          "*.pdf" = "tomoki1207.pdf";
        };
        "vsicons.dontShowNewVersionMessage" = true;
        "github.copilot.inlineSuggest.enable" = false;
        "editor.fontSize" = 12;
        "editor.fontLigatures" = true;
        "editor.fontFamily" = "FiraCode Nerd Font";
        "terminal.integrated.fontFamily" = "FiraCode Nerd Font";
        "terminal.integrated.confirmOnExit" = "hasChildProcesses";
        "editor.minimap.enabled" = false;
        "githubPullRequests.createOnPublishBranch" = "never";
      };
    };
  };
}
