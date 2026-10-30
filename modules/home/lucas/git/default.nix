{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "git-pi5";
      runtimeInputs = [ pkgs.git ];
      text = ''
        if [ $# -gt 1 ]; then
          echo "usage: git pi5 [name]" >&2
          exit 2
        fi

        toplevel=$(git rev-parse --show-toplevel)
        if ! git rev-parse --quiet --verify HEAD >/dev/null; then
          echo "git pi5: $toplevel has no commits to push" >&2
          exit 1
        fi

        name=''${1:-$(basename "$toplevel")}
        name=''${name%.git}
        if [[ ! $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
          echo "git pi5: invalid name '$name', expected [A-Za-z0-9][A-Za-z0-9._-]*" >&2
          exit 2
        fi

        if url=$(git remote get-url pi5 2>/dev/null); then
          echo "git pi5: remote pi5 already points to $url" >&2
          exit 1
        fi

        branch=$(git symbolic-ref --short HEAD)
        path=/srv/git/$name.git
        # mkdir refuses an existing path, so two projects cannot share a name
        create="mkdir $path && git init --quiet --bare --initial-branch=$(printf %q "$branch") $path"
        # pi5 holds no ssh key for itself
        if [ "$(uname -n)" = pi5 ]; then
          url=$path
          sh -c "$create"
        else
          url=pi5:$path
          # shellcheck disable=SC2029
          ssh pi5 "$create"
        fi

        git remote add pi5 "$url"
        git push pi5 --all
        git push pi5 --tags
      '';
    })
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
    ignores = [
      "*.swp"
      ".DS_Store"
    ];
    settings = {
      alias = {
        br = "branch";
        ci = "commit";
        co = "checkout";
        st = "status";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      user = {
        email = "roses.lucas404@gmail.com";
        name = "Lucas de Sousa Rosa";
      };
    };
  };
}
