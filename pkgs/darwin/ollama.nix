{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "ollama-bin";
  version = "0.40.11";
  src = fetchurl {
    url = "https://github.com/ollama/ollama/releases/download/v0.40.11/ollama-darwin.tgz";
    hash = "sha256-rqfT8uMjcbdkSm4uyNTyaCCg45ZZGMzopGzvPpR/YpE=";
  };
  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar -xzf "$src" -C source
    cd source
    runHook postUnpack
  '';
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/ollama" "$out/bin"
    cp -R . "$out/libexec/ollama/"
    ln -s "$out/libexec/ollama/ollama" "$out/bin/ollama"
    runHook postInstall
  '';
  meta = {
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "ollama";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
