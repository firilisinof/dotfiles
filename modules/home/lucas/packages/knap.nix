{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_22,
  makeWrapper,
}:

stdenvNoCC.mkDerivation rec {
  pname = "knap";
  version = "0.6.0";

  # Use the published JavaScript distribution; no TypeScript build is needed.
  src = fetchurl {
    url = "https://registry.npmjs.org/knap/-/knap-${version}.tgz";
    hash = "sha256-5AUryJfbJNTxpE9ZzYJHVRqRSGcimpuhqWk59LAkQuQ=";
  };
  dayjs = fetchurl {
    url = "https://registry.npmjs.org/dayjs/-/dayjs-1.11.23.tgz";
    hash = "sha256-faD/Vd221AULkeoKEajp2SwEgwUVUDk4c3PyC+CA5ZQ=";
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/knap/node_modules/dayjs" "$out/bin"
    cp -r dist package.json LICENSE "$out/lib/knap/"
    tar -xzf "$dayjs" --strip-components=1 -C "$out/lib/knap/node_modules/dayjs"
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/knap" \
      --add-flags "$out/lib/knap/dist/cli.js"
    runHook postInstall
  '';

  meta = {
    description = "Render Markdown templates from structured data";
    homepage = "https://github.com/obsidianmd/knap";
    license = lib.licenses.mit;
    mainProgram = "knap";
    platforms = lib.platforms.all;
  };
}
