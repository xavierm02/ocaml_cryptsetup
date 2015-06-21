INITRD=/boot/initrd.img-$(shell uname -r)

.PHONY: default all clean install uninstall initrd clean

default: all

all: bin/ocaml_cryptsetup

clean:
	ocamlbuild -clean
	rm -rf bin
	rm -rf check

_build/%.native: %.ml $(wildcard src/*.ml)
	ocamlbuild -use-ocamlfind -lib unix -no-links $*.native

bin:
	mkdir bin

bin/%: _build/src/%.native bin
	cp $< $@



INSTALL_FILES=/usr/bin/ocaml_cryptsetup /usr/share/initramfs-tools/hooks/ocaml_cryptsetup /usr/share/initramfs-tools/scripts/local-top/ocaml_cryptsetup

install: $(INSTALL_FILES)

uninstall:
	rm -f $(INSTALL_FILES)

/usr/bin/ocaml_cryptsetup: bin/ocaml_cryptsetup
	cp $< $@

/usr/share/initramfs-tools/hooks/ocaml_cryptsetup: hooks/ocaml_cryptsetup
	cp $< $@

/usr/share/initramfs-tools/scripts/local-top/ocaml_cryptsetup: scripts/local-top/ocaml_cryptsetup
	cp $< $@



initrd: $(INITRD)

$(INITRD): $(INSTALL_FILES)
	sudo update-initramfs -u

check:
	mkdir -p check
	cp $(INITRD) check/initrd.gz
	gunzip check/initrd.gz
	cd check; cpio -i < initrd
	rm check/initrd



.SECONDARY:
