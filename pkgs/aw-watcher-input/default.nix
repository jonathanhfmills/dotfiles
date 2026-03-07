{ lib
, python3Packages
, fetchFromGitHub
, aw-watcher-afk
}:

python3Packages.buildPythonApplication {
  pname = "aw-watcher-input";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "ActivityWatch";
    repo = "aw-watcher-input";
    rev = "9bb5045456524b215ae11f422b80ec728c93bac7";
    hash = "sha256-T7RIzrv+WzA5gEUlU/0dR1Fl0b8zH8q/q80WMBIosPM=";
  };

  pyproject = true;

  nativeBuildInputs = [
    python3Packages.poetry-core
  ];

  propagatedBuildInputs = with python3Packages; [
    aw-client
    click
  ] ++ [
    # aw-watcher-afk provides the KeyboardListener/MouseListener
    aw-watcher-afk
  ];

  # Source lives under src/
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'aw-watcher-afk = {git = "https://github.com/ActivityWatch/aw-watcher-afk.git"}' ""
  '';

  meta = {
    description = "Track keypresses and mouse movements with ActivityWatch (not a keylogger)";
    homepage = "https://github.com/ActivityWatch/aw-watcher-input";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
    mainProgram = "aw-watcher-input";
  };
}
