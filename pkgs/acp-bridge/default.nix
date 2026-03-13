{ lib, stdenv, nodejs_22, makeWrapper }:

stdenv.mkDerivation {
  pname = "acp-bridge";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/lib/acp-bridge $out/bin
    cp acp-bridge.mjs $out/lib/acp-bridge/

    makeWrapper ${nodejs_22}/bin/node $out/bin/acp-bridge \
      --add-flags "$out/lib/acp-bridge/acp-bridge.mjs"
  '';

  meta = with lib; {
    description = "ACP Bridge — CLI-agnostic ACP client bridging any LLM to OpenClaw";
    license = licenses.mit;
    mainProgram = "acp-bridge";
    platforms = [ "x86_64-linux" ];
  };
}
