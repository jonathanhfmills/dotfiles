# Nightly GSPO Training Timer — NAS (i5-13600K CPU + 9070 XT GPU)
# Runs midnight daily. Orchestrates 4 phases:
#   Phase 1: GPU generates K=4 completions/prompt (~15 min)
#   Phase 2: CPU scores with 35B-A3B INT4 (~30 min)
#   Phase 3: ms-swift GSPO trains 9B + 0.8B LoRAs (~1 hr)
#   Phase 4: DSPy/MIPRO prompt optimization (~15 min)
# Total: ~2 hours. GPU stays running for Hermes agent throughout.
# Updated LoRAs sync to workstation via Syncthing by morning.
{ pkgs, config, lib, ... }:

let
  hostname = config.networking.hostName;
  isNas = hostname == "nas";

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pip
    setuptools
    openai
  ]);

  trainingScript = builtins.path {
    path = ../../pkgs/swift-training/train-gspo.sh;
    name = "train-gspo.sh";
  };
in
lib.mkIf isNas {
  # Training data and adapter directories
  systemd.tmpfiles.rules = [
    "d /var/lib/vllm/models/checkpoints 0777 root root -"
    # adapters dir already declared in sglang.nix
    "d /var/lib/vllm/models/dspy 0777 root root -"
  ];

  # Nightly GSPO training timer — midnight daily
  systemd.timers.gspo-training = {
    description = "Nightly GSPO Training Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };

  systemd.services.gspo-training = {
    description = "GSPO Training — nightly distillation from 35B teacher";
    after = [ "docker-sglang.service" ];
    requires = [ "docker-sglang.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${trainingScript}";
      TimeoutStartSec = 14400;  # 4 hours max (generous)
    };
    path = [
      pythonEnv
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    environment = {
      HOME = "/var/lib/vllm";
      PYTHONUSERBASE = "/var/lib/vllm/.local";
      HF_HOME = "/var/lib/vllm/models";
    };
  };
}
