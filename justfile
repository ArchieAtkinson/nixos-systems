update:
    nixos-rebuild switch --flake . --use-remote-sudo
gc:
    nix-collect-garbage -d
    
