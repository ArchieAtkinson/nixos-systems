host := `hostname`

[working-directory: 'os']
os-switch:
    nh os switch . -H {{host}} 

[working-directory: 'home']
hm-switch:
    nh home switch .

clean:
    nh clean all
