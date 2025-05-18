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

    toduiPkg = import ./todui { inherit pkgs; };

    in
    {

      packages.${pkgs.system} = {
        todui = toduiPkg;
     };
    
     nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = pkgs.system;
          specialArgs = { inherit system inputs; };

          modules = [
            ./nixos/configuration.nix
          ];
        };
      };
    };

}
