{ lib
, python3Packages
, fetchFromGitHub
}:

python3Packages.buildPythonApplication {
  pname = "aw-notify";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "ActivityWatch";
    repo = "aw-notify";
    rev = "bcea3cd1a7ffd1ffcb721b952dfa75d11c3bef91";
    hash = "sha256-di508vLHKd6+zyW51/WBxJeXtY5wsICTaDcgKgW3ass=";
  };

  pyproject = true;

  nativeBuildInputs = [
    python3Packages.poetry-core
  ];

  propagatedBuildInputs = with python3Packages; [
    aw-client
    desktop-notifier
  ];

  meta = {
    description = "Screentime notifications using ActivityWatch";
    homepage = "https://github.com/ActivityWatch/aw-notify";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
    mainProgram = "aw-notify";
  };
}
