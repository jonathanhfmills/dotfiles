{ lib
, python3Packages
, fetchFromGitHub
, cosmic-screenshot
, makeWrapper
}:

python3Packages.buildPythonApplication rec {
  pname = "aw-watcher-screenshot-linux";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "jonathanhfmills";
    repo = "aw-watcher-screenshot-linux";
    rev = "aff5cb6";
    hash = "sha256-luzoxCsUiJvWPYf1dKksdCUA5ioERqsc0ODWB5PsEd8=";
  };

  format = "pyproject";

  nativeBuildInputs = [
    python3Packages.setuptools
    makeWrapper
  ];

  propagatedBuildInputs = with python3Packages; [
    aw-client
    aw-core
    click
    imagehash
    pillow
    requests
  ];

  postFixup = ''
    wrapProgram $out/bin/aw-watcher-screenshot-linux \
      --prefix PATH : ${lib.makeBinPath [ cosmic-screenshot ]}
  '';

  meta = {
    description = "ActivityWatch screenshot watcher for Linux — Wayland-native with perceptual dedup";
    homepage = "https://github.com/jonathanhfmills/aw-watcher-screenshot-linux";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "aw-watcher-screenshot-linux";
  };
}
