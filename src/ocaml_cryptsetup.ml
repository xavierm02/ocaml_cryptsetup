open Utils
open Color2
open Conf
open Xor
open Command
open File_utils

let enable_echo () : unit =
  command_with_stdin "stty echo" |> ignore;
  Sys.set_signal Sys.sigint Sys.Signal_default

let disable_echo () : unit =
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ ->
    enable_echo ();
    error ^ " Interrupted!" |> prerr_endline
  ));
  command_with_stdin "stty -echo" |> ignore

let prompt_password () : string =
  let stty_present =
    try
      command "which stty" |> ignore;
      true
    with
    | Command_failed c ->
      (info ^ " " ^ ("stty" |> cyan)
        ^ " is needed to hide the password and the failure of the command "
        ^ (c |> cyan)
        ^ " seems to indicate that it is not installed. "
        ^ "The password will therefore not be hidden.")
        |> prerr_endline;
      false
  in
  if stty_present then
    disable_echo ()
  else ();
  print_string "Password: ";
  flush_all ();
  let password = read_line () in
  if stty_present then begin
    print_newline ();
    enable_echo ()
  end else ();
  password

(*let _ = prompt_password () |> print_endline *)

let _ = wait_for_file "qwe" 10

(*

let cryptsetups make_command =
  let pipes_read, pipes_write =
    encrypted_devices
    |> List.map (ignore %> IO.pipe)
    |> List.split
  in
  let all_pipes_write =
    pipes_write |> List.fold_left
      (fun x y -> fixed_combine (x, y |> IO.cast_output) |> IO.cast_output)
      IO.stdnull
  in
  let password = prompt_password () in
  File.with_file_in "/keys/key_file" (fun key_input ->
    password_xor_key_to_output
      (password |> IO.input_string)
      key_input
      all_pipes_write
  );
  List.iter IO.close_out pipes_write;
  List.combine encrypted_devices pipes_read
  |> List.iter (fun (device, pipe_read) ->
    verbose_command
      ~input:(Some pipe_read)
      (make_command device)
    |> ignore
  )

type command =
  | Mount_keys
  | Umount_keys
  | Create_key_file
  | Open_devices
  | Format_devices
  | Installation_initialize
  | Initramfs_top

exception Unknown_command of string

let command_of_string = function
  | "mount_keys" -> Mount_keys
  | "umount_keys" -> Umount_keys
  | "create_key_file" -> Create_key_file
  | "open_devices" -> Open_devices
  | "format_devices" -> Format_devices
  | "installation_initialize" -> Installation_initialize
  | "Initramfs_top" -> Initramfs_top
  | command -> raise (Unknown_command command)

let string_of_command = function
  | Mount_keys -> "mount_keys"
  | Umount_keys -> "umount_keys"
  | Create_key_file -> "create_key_file"
  | Open_devices -> "open_devices"
  | Format_devices -> "format_devices"
  | Installation_initialize -> "installation_initialize"
  | Initramfs_top -> "Initramfs_top"

let commands = [Mount_keys; Umount_keys; Create_key_file; Open_devices; Format_devices; Installation_initialize; Initramfs_top]

let rec ocaml_cryptsetup = function
  | Mount_keys -> mount key_file_device "/keys" timeout
  | Umount_keys -> umount "/keys" timeout
  | Create_key_file ->
    verbose_simple_command "dd if=/dev/urandom of=/keys/key_file bs=1M count=32";
	  verbose_simple_command "chmod 0400 /keys/key_file"
  | Open_devices -> cryptsetups (fun (device, name) -> "echo cryptsetup luksOpen --key-file - " ^ device ^ " " ^ name)
  | Format_devices -> cryptsetups (fun (device, _) -> "echo cryptsetup luksFormat --key-file - " ^ device)
  | Installation_initialize ->
    [
      Mount_keys;
      Create_key_file;
      Format_devices;
      Open_devices;
      Umount_keys
    ]
    |> List.iter ocaml_cryptsetup
  | Initramfs_top ->
    [
      Mount_keys;
      Open_devices;
      Umount_keys
    ]
    |> List.iter ocaml_cryptsetup

let error_message = "Expected exactly one of the following commands as argument: " ^ (commands |> List.map (string_of_command %> cyan) |> String.join " | ") ^ "."


let _ =
  show_errors (fun () ->
    if Sys.argv |> Array.length <> 2 then
      error ("No argument given! " ^ error_message)
    else ();
    try
      Sys.argv.(1)
      |> command_of_string
      |> ocaml_cryptsetup
    with
    | Unknown_command command -> error ("Unknown command " ^ (command |> cyan) ^ "! " ^ error_message)
  )
*)
