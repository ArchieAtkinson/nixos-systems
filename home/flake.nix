{
  description = "Home Manager configuration of archie";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-yazi-flavors.url = "github:aguirre-matteo/nix-yazi-flavors";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-yazi-flavors,
      ...
    }:
    let
      mkConfig =
        { config, system }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nix-yazi-flavors.overlay ];
          };
          modules = [
            ./configs/${config}.nix
            ./modules/yazi.nix
            ./modules/core-cli.nix
            ./modules/core-gui.nix
            ./modules/fw-dev.nix
            ./modules/nix-tools.nix
          ];
        };
    in
    {
      homeConfigurations = {
        framework = mkConfig {
          config = "framework";
          system = "x86_64-linux";
        };

        xps = mkConfig {
          config = "xps";
          system = "x86_64-linux";
        };
      };
    };

}
