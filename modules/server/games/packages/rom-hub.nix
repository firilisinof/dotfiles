{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  httpx,
  pydantic,
  pyseccomp,
  python-socketio,
}:

buildPythonPackage {
  pname = "rom-hub";
  version = "0.1.0-unstable-2026-08-13";
  pyproject = true;

  # the commit the ROMarr 1.8.0 image installs
  src = fetchFromGitHub {
    owner = "BlizzHacker";
    repo = "rom-hub";
    rev = "8e46348783546ee03b00e2c933155ba60d29619d";
    hash = "sha256-+PBbp9MaK1b3/yu1ZlU69g5Z37Th16LVCU/NNqRAon4=";
  };

  build-system = [ setuptools ];

  dependencies = [
    httpx
    pydantic
    pyseccomp
    python-socketio
  ]
  ++ python-socketio.optional-dependencies.client;

  pythonImportsCheck = [
    "rom_hub"
    "rom_hub_sdk"
  ];

  meta = {
    description = "Plugin host that ROMarr drives for its download sources";
    homepage = "https://github.com/BlizzHacker/rom-hub";
    license = lib.licenses.mit;
    mainProgram = "rom-hub";
    platforms = lib.platforms.linux;
  };
}
