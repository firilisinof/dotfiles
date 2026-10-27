{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  undmg,
  makeWrapper,
}:
{
  pname,
  version,
  url,
  hash,
  app,
  archive,
  license,
  commands ? { },
}:
assert builtins.elem archive [
  "dmg"
  "zip"
];
stdenvNoCC.mkDerivation {
  inherit pname version;
  src = fetchurl {
    inherit url hash;
    name = "${pname}-${version}.${archive}";
  };
  nativeBuildInputs = [ makeWrapper ] ++ (if archive == "dmg" then [ undmg ] else [ unzip ]);
  sourceRoot = ".";
  dontBuild = true;
  # preserve the vendor's signed bundle
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R ${lib.escapeShellArg app} "$out/Applications/"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: executable: ''
        test -x "$out/Applications/${app}/${executable}"
        makeWrapper "$out/Applications/${app}/${executable}" "$out/bin/${name}"
      '') commands
    )}
    runHook postInstall
  '';
  meta = {
    inherit license;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
