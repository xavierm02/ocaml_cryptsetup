open Batteries
open Sys
open Color2

let check_device_exists device =
  try
    if not (file_exists device) then
      error ("The device " ^ device ^ " doesn't exist!")
    else ()
  with
  | Sys_error message -> error message

let check_directory_exists directory =
  try
    if not (file_exists directory) then
      error ("The directory " ^ directory ^ " doesn't exist!")
    else if not (is_directory directory) then
      error ("The file " ^ directory ^ " isn't a directory!")
    else ()
  with
  | Sys_error message -> error message

let stderr2 =
  IO.stderr
  |> IO.synchronize_out

let safe_command command =
  let status = Sys.command command in
  if status <> 0 then
    error ("Command " ^ (command |> cyan) ^ " returned " ^ (string_of_int status) ^ "!")
  else ()

let create_safe_process program arguments input output =
  Unix.create_process program arguments input output Unix.stderr

let mount device directory =
  check_device_exists device;
  check_directory_exists directory;
  safe_command ("mount " ^ device ^ " " ^ directory)
