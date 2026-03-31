host := `hostname`

os-switch:
    nixos-rebuild switch --flake .#{{host}} --sudo

gc:
    nix-collect-garbage -d
    
[working-directory: 'home-manager']
hm-switch:
    home-manager --flake . switch
