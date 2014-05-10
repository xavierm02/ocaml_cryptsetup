#!/bin/zsh

# ZSH is used because it can handle binary data in variables

########
# Test #
########

TEST=0

###########
# Options #
###########

set -e
set -o pipefail

##########
# Output #
##########

say() {
	echo -n "$@" 1>&2
}

######################
# Read configuration #
######################

if  [ -f conf.d/combine-keys ] && [ $TEST -eq 1 ]; then
	. conf.d/combine-keys # test
elif [ -f /conf/conf.d/combine-keys ]; then
	. /conf/conf.d/combine-keys # initramfs
elif [ -f /usr/share/initramfs-tools/conf.d/combine-keys ]; then
	. /usr/share/initramfs-tools/conf.d/combine-keys # normal
else
	say "Could not find the configuration file.\n"
	exit 1
fi

#
# TODO
#

DEVICE_ARRAY=(${=DEVICES})

#########
# Utils #
#########

wait_device() {
	local device
	local attemps
	device=$1
	attempts=0
	until [ -e $device ]; do
		say "Waiting for $device. Sleeping 1s.\n"
		sleep 1
		attempts=$(($attempts + 1))
		if (( $attempts >= 60 )); then
			say "Waited 60s for device. Giving up.\n"
			exit 1
		fi
	done
}

verify_directory() {
	local directory
	directory=$1
	if [ ! -e $directory ]; then
		say "$path does not exists. Attempting to create it...\n"
		mkdir -p $directory
		if [ ! -e $directory ]; then
			say "Failed.\n"
			exit 1
		else
			say "Done\n"
		fi
	elif [ ! -d $directory ]; then
		say "$directory exists but is not a directory.\n"
		exit 1
	fi
}

verbose_mount() {
	local device
	local directory
	device=$1
	directory=$2
	say "Mounting $device on $directory... "
	mount -t ext4 $device $directory
	say "Done.\n"
}

verbose_umount() {
	local directory=$1
	say "Unmounting $directory... "
	umount $directory
	say "Done\n"
}

verify_readability() {
	local file=$1
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

#############
# Functions #
#############

# /keys partition functions

mount_keys() {
	wait_device /dev/$KEYS_DEVICE
	verify_directory $KEYS_PATH
	verbose_mount /dev/$KEYS_DEVICE $KEYS_PATH
	verify_readability $KEYFILE
}

umount_keys() {
	verbose_umount $KEYS_PATH
}

# main functions

prompt_password() {
	local password
	say "Reading password... "
	stty -echo
	read password
	stty echo
	say "Done.\n"
	print -rn $password
}

compute_key() {
	local password
	verify_readability $KEYFILE
	password=$(prompt_password)
	say "Computing key... "
	print -rn $password | xor.bin $KEYFILE
	say "Done.\n"
}

do_to_devices() {
	local cmd
	local key
	cmd=$1
	key=$(compute_key)
	print -r "Devices: $DEVICES"
	for i in "${DEVICE_ARRAY[@]}"; do
		print -rn $key | $cmd "$i"
	done
}

# convenience functions

format_device() {
	local device
	device=$1
	say "Formatting $device with given key... "
	cat /dev/stdin | cryptsetup luksFormat --key-file - "/dev/${device}"
	say "Done.\n"
}

open_device() {
	local device
	device=$1
	say "Opening device $device... "
	cat /dev/stdin | cryptsetup luksOpen --key-file - "/dev/${device}" "${device}_crypt"
	say "Done.\n"
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
format-devices)
	do_to_devices format-device
	exit 0
	;;
open-devices)
	do_to_devices open_device
	exit 0
	;;
installation-initialize)
	do_to_devices format_device
	exit 0
	;;
initramfs-top)
	mount_keys	
	open_devices	
	exit 0
	;;
initramfs-bottom)
	umount_keys
	exit 0
	;;
*)
	echo "Unknown action."
	exit 1
	;;
esac
