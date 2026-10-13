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

    agent-sandbox = {
      url = "github:archie-judd/agent-sandbox.nix/v5.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lan-mouse.url = "github:feschber/lan-mouse";
  };

  nixConfig = {
    extra-substituters = [ "https://lan-mouse.cachix.org/" ];
    extra-trusted-public-keys = [
      "lan-mouse.cachix.org-1:KlE2AEZUgkzNKM7BIzMQo8w9yJYqUpor1CAUNRY6OyM="
    ];
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
            ./modules/lan-mouse.nix
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

      # Per-project dev shells: inputs.nixos-systems.lib.mkOpencodeSandbox { ... } { ... }
      lib = {
        mkOpencodeSandbox = args: (import ./lib/opencode-sandbox.nix args).mkOpencodeSandbox;
        defaultAllowedDomains = args: (import ./lib/opencode-sandbox.nix args).defaultAllowedDomains;
      };
    };

}
