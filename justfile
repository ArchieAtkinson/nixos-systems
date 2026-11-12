host := `hostname`

default: os-switch hm-switch

[working-directory: 'os']
os-switch *ARGS:
    nh os switch . -H {{host}} {{ARGS}} 

[working-directory: 'home']
hm-switch *ARGS:
    nh home switch . -c {{host}} {{ARGS}}

clean:
    nh clean all
