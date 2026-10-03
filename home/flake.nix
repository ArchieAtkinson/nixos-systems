{
  description = "Home Manager configuration of archie";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-yazi-flavors.url = "github:aguirre-matteo/nix-yazi-flavors";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    handy.url = "github:cjpais/Handy";

    opencode.url = "github:anomalyco/opencode/v2.0.22";

    # Declarative bubblewrap/seatbelt sandbox for AI agents.
    agent-sandbox = {
      url = "github:archie-judd/agent-sandbox.nix/v5.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-yazi-flavors,
      zen-browser,
      handy,
      ...
    }@inputs:
    let
      mkConfig =
        { config, system }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nix-yazi-flavors.overlay ];
          };

          extraSpecialArgs = { inherit inputs; };
          modules = [
            zen-browser.homeModules.beta
            ./configs/${config}.nix
            ./modules/yazi.nix
            ./modules/core-cli.nix
            ./modules/core-gui.nix
            ./modules/fw-dev.nix
            ./modules/nix-tools.nix
            ./modules/opencode.nix
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
