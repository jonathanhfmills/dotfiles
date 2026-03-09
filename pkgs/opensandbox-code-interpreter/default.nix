{ python3Packages, fetchFromGitHub, opensandbox-sdk }:

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
  pname = "opensandbox-code-interpreter";
  inherit version;

  sourceRoot = "${src.name}/sdks/code-interpreter/python";
  inherit src;

  pyproject = true;

  build-system = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  dependencies = [
    python3Packages.pydantic
    opensandbox-sdk
  ];

  # hatch-vcs needs git history; override version directly
  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

  doCheck = false;

  meta = {
    description = "OpenSandbox Code Interpreter SDK — multi-language code execution";
    homepage = "https://github.com/alibaba/OpenSandbox";
  };
}
