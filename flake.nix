{
  description = "System Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, ...}@inputs:
  let
    system = "x86_64-linux";
    
    pkgs = import nixpkgs {
      inherit system;

      config = {
        allowUnfree = true;
      };
    };
    
    localPkgsOverlay = pkgs.callPackage ./pkgs {
      inherit (nixpkgs) lib;
      inherit pkgs;
    };

    in
    {    
     nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };

          modules = [
            { nixpkgs.overlays = [ localPkgsOverlay ]; }
            ./nixos/configuration.nix
          ];
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
