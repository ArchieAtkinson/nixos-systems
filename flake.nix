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

    localPkgs = final : prev: {
      local = pkgs.callPackage ./pkgs {};
    };

    in
    {    
     nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };

          modules = [
            { nixpkgs.overlays = [ localPkgs ]; }
            ./nixos/configuration.nix
          ];
        };
      };
    };

}
