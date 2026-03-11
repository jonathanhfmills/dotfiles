{ lib, stdenv, fetchurl, nodejs_22, makeWrapper, ripgrep }:

stdenv.mkDerivation rec {
  pname = "qwen-code";
  version = "0.12.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${version}.tgz";
    hash = "sha256-IpQJGD5zt/5wHnUgy9Erz44S3JLI7KDOBDGcmwjzpS4=";
  };

  nativeBuildInputs = [ makeWrapper ];

  unpackPhase = ''
    tar xzf $src
    sourceRoot=package
  '';

  installPhase = ''
    mkdir -p $out/lib/qwen-code $out/bin
    cp -r . $out/lib/qwen-code/

    # Replace vendored ripgrep with nixpkgs version.
    rm -rf $out/lib/qwen-code/vendor/ripgrep
    mkdir -p $out/lib/qwen-code/vendor/ripgrep/x64-linux
    ln -s ${ripgrep}/bin/rg $out/lib/qwen-code/vendor/ripgrep/x64-linux/rg

    makeWrapper ${nodejs_22}/bin/node $out/bin/qwen \
      --add-flags "$out/lib/qwen-code/cli.js"
  '';

  meta = with lib; {
    description = "Qwen Code — open-source AI coding agent";
    homepage = "https://github.com/QwenLM/qwen-code";
    license = licenses.asl20;
    mainProgram = "qwen";
    platforms = [ "x86_64-linux" ];
  };
}
