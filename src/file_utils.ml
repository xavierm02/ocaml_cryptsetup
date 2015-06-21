open Utils
open Color2
open Command
open Unix

exception Timeout

let wait_for_thing thing check timeout =
  "Waiting for " ^ (thing |> cyan) ^ " for "
    ^ (timeout |> string_of_int |> cyan) ^ " seconds... "
    |> print_string;
  flush_all ();
  let timeout_float = timeout |> float_of_int in
  let start_time = Unix.time () in
  while not (check ()) do
    if Unix.time () -. start_time >= timeout_float then begin
      error |> prerr_endline;
      raise Timeout
    end else begin
      Unix.sleep 1
    end
  done;
  ok |> print_endline

let file_exists path =
  try
    Unix.stat path |> ignore;
    true
  with
  | Unix.Unix_error _ -> false

let wait_for_file path timeout =
  wait_for_thing path (fun () -> file_exists path) timeout

let is_directory path =
  try
    (Unix.stat path).st_kind = Unix.S_DIR
  with
  | Unix.Unix_error _ -> false

let wait_for_directory path timeout =
  wait_for_file path timeout;
  if not (is_directory path) then
    failwith ((path |> cyan) ^ " exists but is not a directory!")
  else ()

let is_device path =
  try
    match (Unix.stat path).st_kind with
    | Unix.S_BLK -> true
    | _ -> false
  with
  | Unix.Unix_error _ -> false

let wait_for_device path timeout =
  wait_for_file path timeout;
  if not (is_device path) then
    failwith ((path |> cyan) ^ " exists but is not a device!")
  else ()

let mount device path timeout =
  wait_for_directory path timeout;
  wait_for_device device timeout;
  "mount " ^ device ^ " " ^ path |> as_root |> command

let umount path timeout =
  wait_for_directory path timeout;
  "umount " ^ path |> as_root |> command

let string_of_char c = String.make 1 c
