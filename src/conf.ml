open Batteries
open Command

let key_file_device = "/dev/disk/by-label/keys"

let encrypted_devices = [
  ("/dev/sda", "hdd_crypt");
  ("/dev/sdb", "ssd_crypt")
]

let timeout = 10
