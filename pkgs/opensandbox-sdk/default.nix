{ python3Packages, fetchFromGitHub }:

let
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "alibaba";
    repo = "OpenSandbox";
    rev = "cb899f990266a879a7d0f743c461c13f1ebccb4f";
    hash = "sha256-+09ZsxCg9xHs9zQbdxTVeX8ideHJoLLY9gR29lIlxQk=";
  };
in
python3Packages.buildPythonPackage {
  pname = "opensandbox";
  inherit version;

  sourceRoot = "${src.name}/sdks/sandbox/python";
  inherit src;

  pyproject = true;

  build-system = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  dependencies = with python3Packages; [
    pydantic
    python-dateutil
    attrs
    httpx
  ];

  # hatch-vcs needs git history; override version directly
  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

  doCheck = false;

  meta = {
    description = "OpenSandbox Python SDK — sandbox lifecycle management";
    homepage = "https://github.com/alibaba/OpenSandbox";
  };
}
