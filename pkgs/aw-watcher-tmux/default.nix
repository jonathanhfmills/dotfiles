{ lib
, fetchFromGitHub
, tmuxPlugins
, curl
, coreutils
, hostname
, gawk
, bash
, makeWrapper
}:

tmuxPlugins.mkTmuxPlugin {
  pluginName = "aw-watcher-tmux";
  rtpFilePath = "aw-watcher-tmux.tmux";
  version = "unstable-2024-01-14";

  src = fetchFromGitHub {
    owner = "akohlbecker";
    repo = "aw-watcher-tmux";
    rev = "efaa7610add52bd2b39cd98d0e8e082b1e126487";
    hash = "sha256-L6YLyEOmb+vdz6bJdB0m5gONPpBp2fV3i9PiLSNrZNM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # Patch the monitor script to have required tools on PATH
    wrapProgram $out/share/tmux-plugins/aw-watcher-tmux/scripts/monitor-session-activity.sh \
      --prefix PATH : ${lib.makeBinPath [ curl coreutils hostname gawk bash ]}
  '';

  meta = {
    description = "ActivityWatch watcher plugin for tmux session tracking";
    homepage = "https://github.com/akohlbecker/aw-watcher-tmux";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
