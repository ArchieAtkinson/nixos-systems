{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    { nixpkgs, sops-nix, ... }@inputs:
    let

      mkSystem =
        { hostname, system }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs hostname; };
          modules = [
            sops-nix.nixosModules.sops
            ./hosts/${hostname}
            ./modules/syncthing.nix
            ./modules/locale.nix
            ./modules/user.nix
            ./modules/virtualisation.nix
            ./modules/vpn.nix
            ./modules/audio.nix
            ./modules/gui.nix
            ./modules/common.nix
            ./modules/xremap.nix
            ./modules/sops.nix
            ./modules/lid-management.nix
            ./modules/udev-rules.nix
            ./modules/rtl28xx.nix
          ];
        };

    in
    {
      nixosConfigurations = {
        xps = mkSystem {
          hostname = "xps";
          system = "x86_64-linux";
        };
        framework = mkSystem {
          hostname = "framework";
          system = "x86_64-linux";
        };

      };

      templates = {
        rust = {
          path = ./templates/rust;
          description = "Rust development environment";
        };
      };
    };
}
