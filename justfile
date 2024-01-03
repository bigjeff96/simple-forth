set shell := ["bash", "-uc"]

find := "/cygdrive/c/cygwin64/bin/find.exe"
exe := "simple-forth.exe"
debug_exe := "simple-forth-debug.exe"

debug:
    odin build . -debug -use-separate-modules -show-timings -out:{{exe}}
    just move_exe

debug_run:
	just debug
	./{{debug_exe}}

watch:
    watchexec -e odin just debug_watch
	
#ignore
debug_watch:
    #!/bin/sh
    odin build . -debug -out:{{exe}}
    clear
    echo -e '\rok'
    just move_exe

release:
    odin build . -o:speed -show-timings -out:{{exe}}
	
#Line count of project
loc:
    tokei -t Odin -o yaml

install:
    just release
    mv {{exe}} /cygdrive/c/Projects/bin/{{exe}}

fmt:
    #!/bin/sh
    for i in $({{ find }} . -name "*.odin" -type f); do
        odinfmt -w "$i"
    done             

move_exe:
    #!/bin/sh
    mv {{exe}} {{debug_exe}}

test:
	odin test .
