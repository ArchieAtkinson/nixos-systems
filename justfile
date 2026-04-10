host := `hostname`

[no-cd]
os-switch:
    nh os switch . -H {{host}} 

[working-directory: 'home-manager']
hm-switch:
    nh home switch .

clean:
    nh clean all
