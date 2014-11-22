open Batteries
open Color2
open Command
open Unix

let verbose_wait thing p timeout =
  verbose_do
    ("Waiting for " ^ (thing |> cyan) ^ " for " ^ (timeout |> string_of_int |> cyan) ^ " seconds...")
    (fun () ->
      let timeout_float = timeout |> float_of_int in
      let start_time = Unix.time () in
      let rec aux () =
        if p () then
          Result ()
        else if Unix.time () -. start_time >= timeout_float then
          Error_message "Timeout!"
        else begin
          Unix.sleep 1;
          aux ()
        end
      in
      aux ()
    )

let check_file_exists path =
  try
    Unix.stat path |> ignore;
    true
  with
  | Unix.Unix_error _ -> prerr_endline "err";false

let verbose_wait_file path timeout =
  verbose_wait
    path
    (fun () -> check_file_exists path)
    timeout

let check_directory_exists path =
  try
    (Unix.stat path).st_kind = Unix.S_DIR
  with
  | Unix.Unix_error _ -> false

let verbose_wait_directory path timeout =
  verbose_wait_file path timeout;
  verbose_assert (check_directory_exists path) ((path |> cyan) ^ " exists but is not a directory!")

let check_device_exists path =
  try
    match (Unix.stat path).st_kind with
    | Unix.S_BLK -> true
    | 	Unix.S_LNK -> prerr_endline "qwe"; false
    | _ -> prerr_endline "nope"; false
  with
  | Unix.Unix_error _ -> false

let verbose_wait_device path timeout =
  verbose_wait_file path timeout;
  verbose_assert (check_device_exists path) ((path |> cyan) ^ " exists but is not a device!")

let mount device path timeout =
  verbose_wait_device device timeout;
  verbose_wait_directory path timeout;
  verbose_simple_command ("mount " ^ device ^ " " ^ path)

let umount path timeout =
  verbose_wait_directory path timeout;
  verbose_simple_command ("umount " ^ path)
