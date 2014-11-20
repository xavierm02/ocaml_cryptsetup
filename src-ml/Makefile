default: all

all: _build/ocaml_cryptsetup.native

test: all
	_build/ocaml_cryptsetup.native test

clean:
	ocamlbuild -clean

.PHONY: default all test clean

_build/%.native: %.ml $(wildcard *.ml)
	ocamlbuild -use-ocamlfind -no-links $*.native
