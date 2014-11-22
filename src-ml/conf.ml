open Batteries
open Command

type device =
  | File of string
  | Uuid of string
  | Label of string

let file_of_device = function
  | File file -> file
  | Uuid uuid -> "/dev/disks/by-uuid/" ^ uuid
  | Label label -> "/dev/disks/by-label" ^ label

let label_of_device = function
  | Label label -> label
  | device -> silent_command ("e2label " ^ (device |> file_of_device))

let key_file_device = Label "keys"

let encrypted_devices = [
  Label "ssd";
  Label "hdd"
]
