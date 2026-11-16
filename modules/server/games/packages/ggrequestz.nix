{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_22,
  python3,
  writeText,
}:

let
  # the image's entrypoint initializes an empty database before migrating, and this is its check
  schemaExists = writeText "schema-exists.cjs" ''
    const { Client } = require("pg");
    const client = new Client({
      host: process.env.POSTGRES_HOST,
      port: process.env.POSTGRES_PORT,
      database: process.env.POSTGRES_DB,
      user: process.env.POSTGRES_USER,
      password: process.env.POSTGRES_PASSWORD,
    });
    client
      .connect()
      .then(() =>
        client.query(
          "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ggr_users')",
        ),
      )
      .then((result) => client.end().then(() => process.exit(result.rows[0].exists ? 0 : 1)))
      .catch((error) => {
        console.error("schema check failed:", error.message);
        process.exit(2);
      });
  '';
in
buildNpmPackage (finalAttrs: {
  pname = "ggrequestz";
  version = "1.5.0";

  # the commit the 1.5.0 image was built from
  src = fetchFromGitHub {
    owner = "XTREEMMAK";
    repo = "ggrequestz";
    rev = "9fa3e42cd77c884fea1ef4aca2dfe060d3a8bbfe";
    hash = "sha256-1RL5onD6O4kZ/Rr1fZTRKyhLmW9b7r4x4puDU9pwomk=";
  };

  npmDepsHash = "sha256-wvfJIzfKS6lnVRDftiYQ5rReYBfng0SKz0OFvSmlT7c=";
  nodejs = nodejs_22;

  # bcrypt compiles its binding
  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  # the image builds with these placeholders, and the real values arrive at run time
  preBuild = ''
    cp .env.docker-build .env
  '';

  # npm pack would leave out the ignored build directory, so install what the image copies
  dontNpmInstall = true;
  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --offline --no-audit --no-fund

    app=$out/lib/ggrequestz
    mkdir -p $app
    cp -r build static package.json scripts migrations src node_modules $app/
    cp ${schemaExists} $app/schema-exists.cjs

    makeWrapper ${lib.getExe finalAttrs.nodejs} $out/bin/ggrequestz \
      --chdir $app \
      --add-flags "--max-old-space-size=1024 $app/build/index.js"

    cat > $out/bin/ggrequestz-migrate <<EOF
    #!/bin/sh
    set -eu
    cd $app
    node=${lib.getExe finalAttrs.nodejs}
    status=0
    \$node schema-exists.cjs || status=\$?
    case \$status in
      0) ;;
      1) \$node scripts/database/db-manager.js init ;;
      *) exit \$status ;;
    esac
    exec \$node scripts/database/db-manager.js migrate
    EOF
    chmod +x $out/bin/ggrequestz-migrate

    runHook postInstall
  '';

  meta = {
    description = "Game discovery and request application";
    homepage = "https://github.com/XTREEMMAK/ggrequestz";
    license = lib.licenses.gpl3Only;
    mainProgram = "ggrequestz";
    platforms = lib.platforms.linux;
  };
})
