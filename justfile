update:
    nixos-rebuild switch --flake .#xps --sudo
gc:
    nix-collect-garbage -d
    
