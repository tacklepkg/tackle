default:
	mkdir -p tmp
	rm -rf docs
	tclsh ./lib/md2html.tcl README.md tmp/overview.html
	tclsh ./lib/tcldoc.tcl \
		--title 'Tackle documentation' \
		--overview tmp/overview.html \
		--header 'Tackle package manager API documentation' \
		docs \
		./src/tackle.tcl
	cp -r ./src/* tmp
	cd tmp; tclsh ../lib/tpack.tcl wrap tackle.tapp
	cp tmp/tackle.tapp ./bin/tackle
	cd tmp; date > test.log
	cd tmp; TACKLEPATH="$PWD" expect ../test.exp ../bin/tackle
	rm -rf tmp

install: default
	chmod +x ./bin/tackle
	mkdir -p ~/.local/bin
	cp ./bin/tackle ~/.local/bin/tackle
