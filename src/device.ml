open Batteries
open Command

type device =
  | File of string
  | Uuid of string
  | Label of string

let file_of_device = function
  | File file -> file
  | Uuid uuid -> "/dev/disk/by-uuid/" ^ uuid
  | Label label -> "/dev/disk/by-label/" ^ label

let label_of_device = function
  | Label label -> label
  | device -> silent_command ("e2label " ^ (device |> file_of_device))
