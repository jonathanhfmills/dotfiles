{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "aw-watcher-window-cosmic";
  version = "0.1.0";

  src = ./.;

  useFetchCargoVendor = true;
  cargoHash = "sha256-2n5YP9NgKGlrKtBciW08dFVzSWpCRFv7/7HHPNJP9dI=";

  meta = {
    description = "ActivityWatch window watcher for COSMIC desktop (Wayland)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "aw-watcher-window-cosmic";
  };
}
