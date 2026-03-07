{ lib
, python3Packages
, fetchFromGitHub
, android-tools
, avahi
, makeWrapper
}:

python3Packages.buildPythonApplication {
  pname = "aw-android-adb";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "jonathanhfmills";
    repo = "aw-android-adb";
    rev = "2a4f9a74232de57ec0357cf32f1f77dd4f305846";
    hash = "sha256-+WMAKF1vqipUoYjMjFK1Hohnm/qRTH1DCFsQZBzWRAI=";
  };

  pyproject = true;

  nativeBuildInputs = [
    python3Packages.poetry-core
    makeWrapper
  ];

  propagatedBuildInputs = with python3Packages; [
    aw-client
    click
  ];

  postFixup = ''
    wrapProgram $out/bin/aw-android-adb \
      --prefix PATH : ${lib.makeBinPath [ android-tools avahi ]}
  '';

  meta = {
    description = "ActivityWatch watcher for Android via ADB";
    homepage = "https://github.com/jonathanhfmills/aw-android-adb";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "aw-android-adb";
  };
}
