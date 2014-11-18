default: all

all: _build/ocaml_cryptsetup.native

clean:
	ocamlbuild -clean

_build/%.native: %.ml $(wildcard *.ml)
	ocamlbuild -use-ocamlfind -no-links $*.native
