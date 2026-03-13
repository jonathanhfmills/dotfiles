{ lib, stdenv, fetchurl, nodejs_22, makeWrapper, ripgrep, autoPatchelfHook }:

let
  # Native addon: PTY for shell command execution
  node-pty = fetchurl {
    url = "https://registry.npmjs.org/@lydell/node-pty/-/node-pty-1.1.0.tgz";
    hash = "sha256-Mbg+3v9cWiIpP+JfcCAsU3m0TBfKP2836bXV9YSjfSc=";
  };
  node-pty-linux-x64 = fetchurl {
    url = "https://registry.npmjs.org/@lydell/node-pty-linux-x64/-/node-pty-linux-x64-1.1.0.tgz";
    hash = "sha256-jS4EMCZnLxGq/V8agx95SpDY/dnV4yVei8Eh32S52OQ=";
  };

  # Native addon: clipboard integration
  clipboard = fetchurl {
    url = "https://registry.npmjs.org/@teddyzhu/clipboard/-/clipboard-0.0.5.tgz";
    hash = "sha256-19PmObu+bj0Uck3KRJz5+gFE7fvSfbg9LtEgrj6gObA=";
  };
  clipboard-linux-x64-gnu = fetchurl {
    url = "https://registry.npmjs.org/@teddyzhu/clipboard-linux-x64-gnu/-/clipboard-linux-x64-gnu-0.0.5.tgz";
    hash = "sha256-RQp1kB7SSvrT3oSUFBVjWLfZoBVCLEDqp61Kqzzv3+E=";
  };
in
stdenv.mkDerivation rec {
  pname = "qwen-code";
  version = "0.12.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${version}.tgz";
    hash = "sha256-IpQJGD5zt/5wHnUgy9Erz44S3JLI7KDOBDGcmwjzpS4=";
  };

  nativeBuildInputs = [ makeWrapper autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

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

    # Install native Node.js addons into node_modules.
    mkdir -p $out/lib/qwen-code/node_modules/@lydell $out/lib/qwen-code/node_modules/@teddyzhu

    tar xzf ${node-pty} -C $out/lib/qwen-code/node_modules/@lydell
    mv $out/lib/qwen-code/node_modules/@lydell/package $out/lib/qwen-code/node_modules/@lydell/node-pty

    tar xzf ${node-pty-linux-x64} -C $out/lib/qwen-code/node_modules/@lydell
    mv $out/lib/qwen-code/node_modules/@lydell/package $out/lib/qwen-code/node_modules/@lydell/node-pty-linux-x64

    tar xzf ${clipboard} -C $out/lib/qwen-code/node_modules/@teddyzhu
    mv $out/lib/qwen-code/node_modules/@teddyzhu/package $out/lib/qwen-code/node_modules/@teddyzhu/clipboard

    tar xzf ${clipboard-linux-x64-gnu} -C $out/lib/qwen-code/node_modules/@teddyzhu
    mv $out/lib/qwen-code/node_modules/@teddyzhu/package $out/lib/qwen-code/node_modules/@teddyzhu/clipboard-linux-x64-gnu

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
