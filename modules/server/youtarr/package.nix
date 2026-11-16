{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_22,
  apprise,
  atomicparsley,
  deno,
  ffmpeg,
  python3,
  yt-dlp,
}:

let
  version = "1.90.2";

  src = fetchFromGitHub {
    owner = "DialmasterOrg";
    repo = "Youtarr";
    tag = "v${version}";
    hash = "sha256-6aNg8v89m8DJqvG1kpgdtUiyyzcTr0RAF8sydZLZAGo=";
  };

  # upstream requires npm 11 only for a release-age setting that npm ci does not use
  relaxEngines = ''
    substituteInPlace .npmrc --replace-fail 'engine-strict=true' 'engine-strict=false'
  '';

  client = buildNpmPackage {
    pname = "youtarr-client";
    inherit version;
    src = "${src}/client";
    npmDepsHash = "sha256-SZMyoKIoH8mxegq3lWsHMUtWUi8L0uPlCbPLiEMb8dE=";
    nodejs = nodejs_22;
    npmFlags = [ "--ignore-scripts" ];
    postPatch = relaxEngines;

    installPhase = ''
      runHook preInstall
      cp -r build $out
      runHook postInstall
    '';
  };
in
buildNpmPackage (finalAttrs: {
  pname = "youtarr";
  inherit version src;

  npmDepsHash = "sha256-lCS+L5BPn9xFR7aGfPgQhQO26UTL9EW0BtxeMfADhSU=";
  nodejs = nodejs_22;
  # the image installs without lifecycle scripts too
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postPatch = relaxEngines + ''
    # the host database has networking disabled, and upstream only opens tcp sockets
    substituteInPlace server/modules/databaseSocket.js \
      --replace-fail \
        'const socket = net.connect({ host, port, lookup: this.lookup });' \
        'const socket = process.env.DB_SOCKET_PATH ? net.connect(process.env.DB_SOCKET_PATH) : net.connect({ host, port, lookup: this.lookup });'
    # upstream listens on every interface and leaves the restriction to the container's port mapping
    substituteInPlace server/server.js \
      --replace-fail \
        'server.listen(port, () => {' \
        "server.listen(port, process.env.HOST || '0.0.0.0', () => {"
  '';

  # npm pack would leave out the client build, so install what the image copies
  dontNpmInstall = true;
  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --offline --ignore-scripts --no-audit --no-fund

    app=$out/lib/youtarr
    mkdir -p $app/client
    cp -r server migrations package.json node_modules $app/
    cp -r ${client} $app/client/build
    cp config/config.example.json $app/server/config.example.json
    # upstream keeps its state beside the code, and the service binds its state directories here
    mkdir -p $app/config $app/jobs $app/server/images

    makeWrapper ${lib.getExe finalAttrs.nodejs} $out/bin/youtarr \
      --add-flags "$app/server/server.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          apprise
          atomicparsley
          deno
          ffmpeg
          finalAttrs.nodejs
          python3
          yt-dlp
        ]
      }

    runHook postInstall
  '';

  passthru = { inherit client; };

  meta = {
    description = "Self-hosted YouTube downloader and archive";
    homepage = "https://github.com/DialmasterOrg/Youtarr";
    license = lib.licenses.isc;
    mainProgram = "youtarr";
    platforms = lib.platforms.linux;
  };
})
