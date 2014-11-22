open Batteries
open Command

let key_file_device = "/dev/disk/by-label/keys"

let encrypted_devices = [
  ("/dev/sda", "hdd");
  ("/dev/sdb", "ssd")
]

let timeout = 10
