host := `hostname`

update:
    nixos-rebuild switch --flake .#{{host}} --sudo

gc:
    nix-collect-garbage -d
    
