CC=gcc -Wall -Wextra

include conf.d/combine-keys

.PHONY: all clean

all: bin/xor.bin

clean:
	rm -rf bin
	rm -rf *~ **/*~
	rm -rf check

install: bin/xor.bin
	sudo cp bin/xor.bin $(NORMAL_BIN)/$(XOR_NAME)
	sudo cp src/combine-keys.sh $(NORMAL_BIN)/$(COMBINE_KEYS_NAME)
	sudo cp -r conf.d/* /usr/share/initramfs-tools/conf.d
	sudo cp -r scripts/* /usr/share/initramfs-tools/scripts
	sudo cp -r hooks/* /usr/share/initramfs-tools/hooks

update:
	sudo update-initramfs -u

check:
	mkdir -p check
	cp /boot/initrd.img-`uname -r` check/initrd.gz
	gunzip check/initrd.gz
	cd check; cpio -i < initrd
	rm check/initrd



bin:
	mkdir bin

bin/%.bin: src/%.c bin
	$(CC) -o $@ $<
