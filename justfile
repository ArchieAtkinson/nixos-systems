update:
    nixos-rebuild switch --flake . --sudo
gc:
    nix-collect-garbage -d
    
