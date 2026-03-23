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
        davidanson.vscode-markdownlint
        dbaeumer.vscode-eslint
        dotjoshjohnson.xml
        esbenp.prettier-vscode
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
        redhat.vscode-yaml
        shd101wyy.markdown-preview-enhanced
        tamasfe.even-better-toml
        tomoki1207.pdf
        vscode-icons-team.vscode-icons
        vscodevim.vim
        yzhang.markdown-all-in-one
      ];

      userSettings = {
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";
        "extensions.autoCheckUpdates" = false;
        "window.titleBarStyle" = "custom";
        "workbench.startupEditor" = "none";
        "workbench.colorTheme" = "Visual Studio Light";
        "workbench.iconTheme" = "vscode-icons";
        "vsicons.dontShowNewVersionMessage" = true;
        "editor.fontSize" = 12;
        "editor.fontLigatures" = true;
        "editor.fontFamily" = "FiraCode Nerd Font";
        "terminal.integrated.fontFamily" = "FiraCode Nerd Font";
        "terminal.integrated.confirmOnExit" = "hasChildProcesses";
        "explorer.excludeGitIgnore" = true;
      };
    };
  };
}
