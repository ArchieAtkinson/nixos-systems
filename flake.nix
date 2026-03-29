{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }@inputs:
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
            common
            ./hosts/${hostname}
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
