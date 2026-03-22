This repository manages a macOS system with `nix-darwin`, Home Manager, and `nix-homebrew`.

Keep changes small, direct, and declarative.

Repository structure:

- `flake.nix` is the main entrypoint.
- `modules/darwin/` contains nix-darwin modules.
- `modules/home/lucas/` contains Home Manager modules for the `lucas` user.

Module conventions:

- Keep top-level entry modules thin.
- Put shared darwin imports in `modules/darwin/default.nix`.
- Put shared home imports in `modules/home/lucas/default.nix`.
- Split settings by concern, not by tool type. Examples: `git/`, `zsh/`, `aerospace/`, `homebrew.nix`, `system-defaults.nix`.
- If a module may grow, prefer a directory with `default.nix`.
- Avoid putting unrelated settings back into one large file.

Darwin conventions:

- Keep Homebrew configuration under `modules/darwin/homebrew.nix`.
- Keep macOS defaults under `modules/darwin/system-defaults.nix`.
- Keep security, keyboard, platform, and versioning in separate files.

Home Manager conventions:

- Configure packages in `modules/home/lucas/packages.nix`.
- Configure shell/session environment in dedicated modules such as `environment.nix`.
- Prefer Home Manager program modules like `programs.git`, `programs.zsh`, and `programs.neovim` over manually installing duplicate packages.

Validation:

- Run `nix flake check` after changing Nix modules.

Git workflow:

- Use conventional commit messages.
- Keep commit scopes short and meaningful, for example: `feat(home): ...`, `chore(darwin): ...`.
- Do not add a `Co-Authored-By` trailer or any mention of AI tools in commit messages.

When editing:

- Prefer extending the existing module layout instead of creating parallel patterns.
- Use absolute paths where environment-sensitive values matter.
- Avoid imperative one-off setup when the same thing can be expressed in Nix.
- Use homebrew for GUI packages and packages not found in nixpkgs.
- Just make meaningful comments. The code should be readable by itself.
