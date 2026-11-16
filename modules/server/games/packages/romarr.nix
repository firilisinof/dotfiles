{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python313,
  libarchive,
  git,
}:

let
  python = python313.override {
    self = python;
    packageOverrides = final: _: {
      pyseccomp = final.callPackage ./pyseccomp.nix { };
      rom-hub = final.callPackage ./rom-hub.nix { };
    };
  };
  # ROM Hub starts plugins with this interpreter and expects its rom-hub script beside it
  pythonEnv = python.withPackages (ps: [
    ps.requests
    ps.pyseccomp
    ps.rom-hub
  ]);
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "romarr";
  version = "1.8.0";

  src = fetchFromGitHub {
    owner = "BlizzHacker";
    repo = "romarr";
    rev = "0e9e03c58167d98441d85a2734aed58aa7ecb869";
    hash = "sha256-kEc7Y3DsZ5d3bMJGJeu5EGrPxQQ3CXWahrUjZg+lTMg=";
  };

  strictDeps = true;
  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  # upstream has no installer, its image copies the package and runs it as a module
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/romarr
    cp -r romarr $out/share/romarr/romarr
    echo '__version__ = "${finalAttrs.version}"' > $out/share/romarr/romarr/_version.py

    # bsdtar reads the 7z and rar archives, and ROM Hub installs plugins with git
    makeWrapper ${pythonEnv}/bin/python $out/bin/romarr \
      --add-flags "-m romarr" \
      --prefix PYTHONPATH : $out/share/romarr \
      --prefix PATH : ${
        lib.makeBinPath [
          libarchive
          git
        ]
      }

    runHook postInstall
  '';

  passthru = { inherit pythonEnv; };

  meta = {
    description = "Finds, downloads, and files ROMs into a game library";
    homepage = "https://github.com/BlizzHacker/romarr";
    license = lib.licenses.mit;
    mainProgram = "romarr";
    platforms = lib.platforms.linux;
  };
})
