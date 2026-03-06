{ lib, rustPlatform, fetchFromGitHub, pkg-config, openssl, wayland }:

rustPlatform.buildRustPackage {
  pname = "aw-watcher-window-wayland";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "jonathanhfmills";
    repo = "aw-watcher-window-wayland";
    rev = "898a50789e79913683d6459af3d27e48091650fc";
    hash = "sha256-GzD5yx1kqef8DjZ34TPcNYIo5aWnZYKganKRAMTXdRk=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl wayland ];

  useFetchCargoVendor = true;
  cargoHash = "";

  meta = {
    description = "ActivityWatch window and AFK watcher for Wayland (wlroots + COSMIC)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "aw-watcher-window-wayland";
  };
}
