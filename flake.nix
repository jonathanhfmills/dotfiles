{
  description = "NixOS multi-host configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nullclaw = {
      url = "github:nullclaw/nullclaw";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, disko, agenix, claude-code, nullclaw, ... }:
  let
    localOverlay = final: prev: {
      aw-watcher-window-wayland = final.callPackage ./pkgs/aw-watcher-window-wayland {};
      aw-watcher-screenshot-linux = final.callPackage ./pkgs/aw-watcher-screenshot-linux {};
      aw-watcher-input = final.callPackage ./pkgs/aw-watcher-input {};
      aw-notify = final.callPackage ./pkgs/aw-notify {};
      aw-android-adb = final.callPackage ./pkgs/aw-android-adb {};
      aw-watcher-bash = final.callPackage ./pkgs/aw-watcher-bash {};
      tmuxPlugins = prev.tmuxPlugins // {
        aw-watcher-tmux = final.callPackage ./pkgs/aw-watcher-tmux {};
      };
      opensandbox-sdk = final.callPackage ./pkgs/opensandbox-sdk {};
      opensandbox-code-interpreter = final.callPackage ./pkgs/opensandbox-code-interpreter {
        opensandbox-sdk = final.opensandbox-sdk;
      };
      qwen-code = final.callPackage ./pkgs/qwen-code {};
      acp-bridge = final.callPackage ./pkgs/acp-bridge {};
      acp-reasoning-image = final.callPackage ./pkgs/acp-bridge/docker-image.nix {
        acp-bridge = final.acp-bridge;
        qwen-code = final.qwen-code;
      };
    };
    overlayModule = { nixpkgs.overlays = [ localOverlay ]; };
  in {

    # Desktop (ext4 root — legacy config, kept for dual-boot fallback).
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit claude-code nullclaw; };
      modules = [
        overlayModule
        ./hosts/desktop
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/programs/nullclaw.nix
        ./modules/programs/qwen-code.nix
        ./modules/programs/activitywatch.nix
        ./modules/services/syncthing.nix
        ./modules/services/dnscrypt-proxy.nix
        ./modules/services/stremio-server.nix
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jon = { imports = [ ./modules/users/jon.nix ./modules/users/cosmic-desktop.nix ]; };
          home-manager.users.jon-private = import ./modules/users/jon-private.nix;
        }
      ];
    };

    # Desktop (ZFS root — 990 PRO 2TB from workstation).
    # Runs COSMIC desktop + agent compute (no local GPU — uses NAS vLLM via Tailscale).
    nixosConfigurations.desktop-zfs = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit claude-code nullclaw nixpkgs-unstable; };
      modules = [
        overlayModule
        ./hosts/desktop
        ./hosts/desktop/hardware-zfs.nix
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/programs/nullclaw.nix
        ./modules/programs/qwen-code.nix
        ./modules/programs/activitywatch.nix
        ./modules/services/syncthing.nix
        ./modules/services/dnscrypt-proxy.nix
        ./modules/services/stremio-server.nix
        # No agent compute — desktop-zfs is a fallback config without GPU
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jon = { imports = [ ./modules/users/jon.nix ./modules/users/cosmic-desktop.nix ]; };
          home-manager.users.jon-private = import ./modules/users/jon-private.nix;
        }
      ];
    };

    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit claude-code nullclaw nixpkgs-unstable; };
      modules = [
        overlayModule
        ./hosts/workstation
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/programs/nullclaw.nix
        ./modules/services/sglang-nvidia.nix
        ./modules/services/sglang-classifier.nix
        ./modules/services/caddy.nix
        ./modules/services/dnscrypt-proxy.nix
        ./modules/services/stremio-server.nix
        ./modules/services/syncthing.nix
        ./modules/services/opensandbox.nix
        ./modules/services/agent-runner.nix
        ./modules/programs/qwen-code.nix
        ./modules/programs/activitywatch.nix
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jon = import ./modules/users/jon.nix;
        }
      ];
    };

    nixosConfigurations.nas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit claude-code nullclaw nixpkgs-unstable; };
      modules = [
        overlayModule
        ./hosts/nas
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/programs/nullclaw.nix
        ./modules/services/sglang.nix
        ./modules/services/sglang-evaluator.nix
        ./modules/services/caddy.nix
        ./modules/services/dnscrypt-proxy.nix
        ./modules/services/stremio-server.nix
        ./modules/programs/qwen-code.nix
        ./modules/services/syncthing.nix
        ./modules/services/opensandbox.nix
        ./modules/services/orchestrator.nix
        ./modules/services/agent-runner.nix
        ./modules/programs/activitywatch.nix
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jon = import ./modules/users/jon.nix;
        }
      ];
    };

    nixosConfigurations.portable = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit claude-code; };
      modules = [
        overlayModule
        ./hosts/portable
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/services/dnscrypt-proxy.nix
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jon = import ./modules/users/jon.nix;
        }
      ];
    };

    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit claude-code nullclaw; };
      modules = [
        overlayModule
        ./hosts/laptop
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/programs/nullclaw.nix
        ./modules/programs/qwen-code.nix
        ./modules/programs/activitywatch.nix
        ./modules/services/syncthing.nix
        ./modules/services/dnscrypt-proxy.nix
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jon = import ./modules/users/jon.nix;
          home-manager.users.jon-private = import ./modules/users/jon-private.nix;
        }
      ];
    };
  };
}
