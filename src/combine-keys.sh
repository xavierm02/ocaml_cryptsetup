#!/bin/bash

set -e
set -o pipefail

if [ -f /conf/conf.d/combine-keys ]; then
	. /conf/conf.d/combine-keys
else
	. /usr/share/initramfs-tools/conf.d/combine-keys
fi

DEVICE_ARRAY=($DEVICES)

say() {
	printf "$@" 1>&2
}

wait_device() {
	device=$1
	attempts=0
	until [ -e $device ]; do
		say "Waiting for $device. Sleeping 1s.\n"
		sleep 1
		attempts+=1
		if (( $attempts >= 60 )); then
			say "Waited 60s for device. Giving up.\n"
			exit 1
		fi
	done
}

verify_path() {
	path=$1
	if [ ! -e $path ]; then
		say "$path does not exists. Attempting to create it...\n"
		mkdir -p $path
		if [ ! -e $path ]; then
			say "Failed.\n"
			exit 1
		else
			say "Done\n"
		fi
	elif [ ! -d $path ]; then
		say "$path exists but is not a directory.\n"
		exit 1
	fi
}

verbose_mount() {
	device=$1
	path=$2
	say "Mounting $device on $path...\n"
	mount -t ext4 $device $path
	say "Done.\n"
}

verbose_umount() {
	path=$1
	say "Unmounting $path...\n"
	umount $path
	say "Done\n"
}

verify_readability() {
	file=$1
	if [ ! -e $file ]; then
		say "$file does not exists.\n"
		exit 1
	elif [ ! -f $file ]; then
		say "$file if not a file.\n"
		exit 1
	elif [ ! -r $file ]; then
		say "Can not read $file.\n"
		exit 1
	fi
}



mount_keys() {
	wait_device $KEYS_DEVICE
	verify_path $KEYS_PATH
	verbose_mount /dev/$KEYS_DEVICE $KEYS_PATH
	verify_readability $KEYFILE
}

umount_keys() {
	verbose_umount $KEYS_PATH
}

prompt_password() {
	say "Reading password...\n"
	stty -echo
	read password
	stty echo
	say "Done reading password.\n"
	echo -n $password
}

compute_key() {
	verify_readability $KEYFILE
	say "Computing key...\n"
	prompt_password | xor.bin $KEYFILE
	say "Done computing key.\n"
}

do_to_devices() {
	local cmd=$1
	for i in "${DEVICE_ARRAY[@]}";do
		mkfifo /tmp/"$i"_fifo
		$cmd "$i" </tmp/"$i"_fifo &
	done
	compute_key | tee /tmp/*_fifo >/dev/null
	rm -f /tmp/*_fifo
}

open_device() {
	device=$1
	cat /dev/stdin | cryptsetup luksOpen -d - "/dev/${device}" "${device}_crypt"
}

open_devices() {
	say "Opening devices...\n"
	do_to_devices open_device
	printf "Done opening devices.\n"
}

case $1 in
mount-keys)
	mount_keys
	exit 0
	;;
umount-keys)
	umount_keys
	exit 0
	;;
compute-key)
	compute_key
	exit 0
	;;
open-all)
	open_devices
	exit 0
	;;
top)
	mount_keys	
	open_devices	
	exit 0
	;;
bottom)
	umount_keys
	exit 0
	;;
*)
	echo "Unknown action."
	exit 1
	;;
esac
