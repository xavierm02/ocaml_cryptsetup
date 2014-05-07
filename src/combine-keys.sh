#!/bin/sh

if [ -f /conf/conf.d/combine-keys ]; then
	. /conf/conf.d/combine-keys
else
	. /usr/share/initramfs-tools/conf.d/combine-keys
fi

wait_device() {
	device=$1
	attempts=0
	until [ -e $device ]; do
		echo "Waiting for $device. Sleeping 1s."
		sleep 1
		attempts=$(($attempts + 1))
		if [ $attempts -ge 60 ]; then
			echo "Waited 60s for device. Giving up."
			exit 1
		fi
	done
}

verify_path() {
	path=$1
	if [ ! -e $path ]; then
		echo -n "$path does not exists. Attempting to create it... "
		mkdir -p $path
		if [ ! -e $path ]; then
			echo "Failed."
			exit 1
		else
			echo "Done"
		fi
	elif [ ! -d $path ]; then
		echo "$path exists but is not a directory."
		exit 1
	fi
}

verbose_mount() {
	device=$1
	path=$2
	echo -n "Mounting $device on $path... "
	mount -t ext4 $device $path
	echo "Done."
}

verify_readability() {
	file=$1
	if [ ! -e $file ]; then
		echo "$file does not exists."
		exit 1
	elif [ ! -f $file ]; then
		echo "$file if not a file."
		exit 1
	elif [ ! -r $file ]; then
		echo "Can not read $file."
		exit 1
	fi
}

mount_keys() {
	wait_device $KEYS_DEVICE
	verify_path $KEYS_PATH
	verbose_mount $KEYS_DEVICE $KEYS_PATH
	verify_readability $KEYFILE
}

umount_keys() {
	umount $KEYS_PATH
}

mount_usb_tmp() {
	wait_device $TMP_DEVICE
	verify_path $TMP_PATH
	cryptsetup open --type plain -d /dev/urandom $TMP_DEVICE $TMP_MAPPER_NAME
	mkfs.ext4  $TMP_MAPPER
	verbose_mount $TMP_MAPPER $TMP_PATH
}

umount_usb_tmp() {
	umount $TMP_PATH
	cryptsetup close $TMP_MAPPER
}

compute_key() {
	stty -echo
	printf "Password: "
	read password
	stty echo
	printf "\n"
	echo $password
	echo -n "Computing key and writing it to $KEY. "
	echo -n $password | xor.bin $KEYFILE > $KEY
	echo "Done."
}

delete_key() {
	rm -f $KEY
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
mount-usb-tmp)
	mount_usb_tmp
	exit 0
	;;
umount-usb-tmp)
	umount_usb_tmp
	exit 0
	;;
compute-key)
	compute_key
	exit 0
	;;
top)
	mount_keys
	mount_usb_tmp
	compute_key
	exit 0
	;;
bottom)
	delete_key
	umount_usb_tmp
	umount_keys
	exit 0
	;;
*)
	echo "Unknown action."
	exit 1
	;;
esac
