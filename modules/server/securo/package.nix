{
  lib,
  callPackage,
  buildNpmPackage,
  nodejs_22,
  python314,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  src,
}:

let
  version = "0.18.0";

  # the image installs exactly what uv.lock resolves, and so does this
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src + "/backend"; };
  pythonSet = (callPackage pyproject-nix.build.packages { python = python314; }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
      # ofxparse ships only an sdist without a declared build system
      (final: prev: {
        ofxparse = prev.ofxparse.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ final.resolveBuildSystem { setuptools = [ ]; };
        });
      })
    ]
  );
in
{
  inherit version;

  # alembic.ini and the migrations are not part of the python package, so services run from here
  backend = src + "/backend";

  env = pythonSet.mkVirtualEnv "securo-env-${version}" workspace.deps.default;

  frontend = buildNpmPackage {
    pname = "securo-frontend";
    inherit version;
    src = src + "/frontend";
    npmDepsHash = "sha256-d6GNm9lm7MpbFpZxwFjkrxp4YZsPQYlgr0T4k68Ffe0=";
    nodejs = nodejs_22;

    env.VITE_APP_VERSION = version;

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
}
