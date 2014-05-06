CC=gcc -Wall -Wextra

include conf.d/combine-keys

.PHONY: all clean

all: bin/xor.bin

clean:
	rm -rf bin
	rm -rf *~ **/*~

install: bin/xor.bin
	sudo cp bin/xor.bin $(XOR)
	sudo cp src/combine-keys.sh $(COMBINE_KEYS)
	sudo cp -r conf.d/* /usr/share/initramfs-tools/conf.d
	sudo cp -r scripts/* /usr/share/initramfs-tools/scripts
	sudo cp -r hooks/* /usr/share/initramfs-tools/hooks

update:
	sudo update-initramfs -u



bin:
	mkdir bin

bin/%.bin: src/%.c bin
	$(CC) -o $@ $<
