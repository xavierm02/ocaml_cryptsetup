CC=gcc -Wall -Wextra
INSTALL_DEPENDANCIES=conf.d/combine-keys hooks/conf.d Makefile scripts/local-top/combine-keys scripts/local-bottom/combine-keys src/combine-keys.sh bin/xor.bin
INITRD=/boot/initrd.img-$(shell uname -r)

include conf.d/combine-keys



.PHONY: all xor install uninstall initrd clean



all: xor


bin:
	mkdir bin

bin/%.bin: src/%.c bin
	$(CC) -o $@ $<

xor: bin/xor.bin



INSTALL_FILES=/usr/share/initramfs-tools/conf.d/combine-keys $(NORMAL_BIN)/$(COMBINE_KEYS_NAME) $(NORMAL_BIN)/$(XOR_NAME) /usr/share/initramfs-tools/hooks/combine-keys /usr/share/initramfs-tools/scripts/local-top/combine-keys /usr/share/initramfs-tools/scripts/local-bottom/combine-keys

install: $(INSTALL_FILES)

uninstall:
	sudo rm -f $(INSTALL_FILES)

/usr/share/initramfs-tools/conf.d/combine-keys: conf.d/combine-keys
	sudo cp conf.d/combine-keys /usr/share/initramfs-tools/conf.d/combine-keys

$(NORMAL_BIN)/$(COMBINE_KEYS_NAME): src/combine-keys.sh
	sudo cp src/combine-keys.sh $(NORMAL_BIN)/$(COMBINE_KEYS_NAME)

$(NORMAL_BIN)/$(XOR_NAME): bin/xor.bin
	sudo cp bin/xor.bin $(NORMAL_BIN)/$(XOR_NAME)

/usr/share/initramfs-tools/hooks/combine-keys: hooks/combine-keys
	sudo cp hooks/combine-keys /usr/share/initramfs-tools/hooks/combine-keys

/usr/share/initramfs-tools/scripts/local-top/combine-keys: scripts/local-top/combine-keys
	sudo cp scripts/local-top/combine-keys /usr/share/initramfs-tools/scripts/local-top/combine-keys

/usr/share/initramfs-tools/scripts/local-bottom/combine-keys: scripts/local-bottom/combine-keys
	sudo cp scripts/local-bottom/combine-keys /usr/share/initramfs-tools/scripts/local-bottom/combine-keys



initrd: $(INITRD)

$(INITRD): $(INSTALL_FILES)
	sudo update-initramfs -u



check: $(INITRD)
	mkdir -p check
	cp $(INITRD) check/initrd.gz
	gunzip check/initrd.gz
	cd check; cpio -i < initrd
	rm check/initrd



clean:
	rm -rf bin
	rm -rf *~ **/*~
	rm -rf check

