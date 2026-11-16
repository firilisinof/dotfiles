{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  libseccomp,
}:

buildPythonPackage (finalAttrs: {
  pname = "pyseccomp";
  version = "0.1.2";
  pyproject = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-DVTvrPcb2kvf0hIz9URLcwy+z1k9YC95bmQSqGgiWL0=";
  };

  # ctypes.util.find_library needs a compiler or ldconfig, which NixOS services do not have
  postPatch = ''
    substituteInPlace pyseccomp.py \
      --replace-fail 'ctypes.util.find_library("seccomp")' '"${lib.getLib libseccomp}/lib/libseccomp.so.2"'
  '';

  build-system = [ setuptools ];

  pythonImportsCheck = [ "pyseccomp" ];

  meta = {
    description = "Interface to libseccomp using ctypes";
    homepage = "https://github.com/cptpcrd/pyseccomp";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
