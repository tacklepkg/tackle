# Tackle

A package manager for the Tcl programming language.

![Makefile CI](https://github.com/tacklepkg/tackle/actions/workflows/makefile.yml/badge.svg)
![Size](https://img.shields.io/github/size/tacklepkg/tackle/bin/tackle)
![Downloads](https://img.shields.io/github/downloads/tacklepkg/tackle/total)

For more information, API documenation, etc., please visit:
[tacklepkg.com](https://www.tacklepkg.com)

## Synopsis

Packages are
[pretty straightforward](https://www.tcl.tk/man/tcl8.5/tutorial/Tcl31.html)
in Tcl, but manually moving around directories is a bit of a pain.
Tackle helps automate this process by managing directories of packages and
modules.

| command                           | description                              |
|-----------------------------------|------------------------------------------|
| `$ tackle package search $query`  | Search for available packages by `$query`|
| `$ tackle package add $names`     | Install packages by `$names`             |
| `$ tackle package rm  $names`     | Uninstall packages by `$names`           |
| `$ tackle package ls`             | List installed packages                  |
| `$ tackle package show $name`     | Detail an installed package by `$name`   |


## Usage

Tackle works by fetching Tcl package tarballs or module files from the web.
One can add or remove packages like this:

```bash
$ tackle search tut
tutstack v1.0.0
  An example Tcl package that implements a simple data structure
  Package URL: https://github.com/tacklepkg/packages/raw/master/tutstack/tutstack.tar.gz
$ tackle add tutstack
Added package tutstack v1.0.0
from https://github.com/tacklepkg/packages/raw/master/tutstack/tutstack.tar.gz
to /home/username/.local/share/tackle/tutstack
Done.
$ tackle ls
tutstack
```

## Installation

1. Make sure you have Tcl version 8.6 or greater installed.
2. Set environment variables, e.g. for Fish shell:
```fish
$ set -Ux TCLLIBPATH $TCLLIBPATH ~/.local/share/tackle/
$ set -Ux TCL8_6_TM_PATH $TCL8_6_TM_PATH ~/.local/share/tackle/
```
3. Download the `tackle` script and place it somewhere in your `$PATH`.

## Contributing

In order to build Tackle you need Tcl 8.6+, Expect, and Make installed.

A simple `$ make` will bundle dependencies, generate documentation,
and run the test suite. `$ make install` marks the bundle as executable
and installs it to `~/.local/bin/tackle`.



Help improve Tackle on [GitHub](https://github.com/tacklepkg/tackle).
