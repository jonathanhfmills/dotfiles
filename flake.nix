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
  };

  outputs = { self, nixpkgs, home-manager, disko, agenix, ... }: {
    # Desktop (ext4 root — legacy config, kept for dual-boot fallback).
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/desktop
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/programs/ironclaw.nix
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jon = { imports = [ ./modules/users/jon.nix ./modules/users/cosmic-desktop.nix ]; };
        }
      ];
    };

    # Desktop (ZFS root — new primary config).
    nixosConfigurations.desktop-zfs = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/desktop
        ./hosts/desktop/hardware-zfs.nix
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/programs/ironclaw.nix
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.jon = { imports = [ ./modules/users/jon.nix ./modules/users/cosmic-desktop.nix ]; };
        }
      ];
    };

    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/workstation
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/services/ollama.nix
        ./modules/services/caddy.nix
        ./modules/services/dnscrypt-proxy.nix
        ./modules/programs/ironclaw.nix
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
      modules = [
        ./hosts/nas
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/services/ollama-nvidia.nix
        ./modules/services/caddy.nix
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

    nixosConfigurations.portable = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/portable
        ./modules/base.nix
        ./modules/networking.nix
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
      modules = [
        ./hosts/laptop
        ./modules/base.nix
        ./modules/networking.nix
        ./modules/development.nix
        ./modules/programs/1password.nix
        ./modules/programs/ironclaw.nix
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
  };
}
