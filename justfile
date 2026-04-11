host := `hostname`

[working-directory: 'os']
os-switch *ARGS:
    nh os switch . -H {{host}} {{ARGS}} 

[working-directory: 'home']
hm-switch *ARGS:
    nh home switch . {{ARGS}}

clean:
    nh clean all
