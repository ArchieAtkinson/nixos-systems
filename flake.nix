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

      common =
        { ... }:
        {
          config = {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              (final: prev: {
                localPkgs = final.callPackage ./pkgs { inherit (nixpkgs) lib; };
              })
            ];
          };
        };

      mkSystem =
        { hostname, system }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs hostname; };
          modules = [
            sops-nix.nixosModules.sops
            common
            ./hosts/${hostname}
            ./modules/common.nix
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

      };

      templates = {
        rust = {
          path = ./templates/rust;
          description = "Rust development environment";
        };
      };
    };
}
