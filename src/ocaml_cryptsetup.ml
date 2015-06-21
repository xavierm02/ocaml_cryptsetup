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

type command =
  | Mount_key_device
  | Umount_key_device
  | Create_keyfile
  | Open_devices
  | Format_devices
  | Installation_initialize
  | Initramfs_top

let commands =
  [
    Mount_key_device;
    Umount_key_device;
    Create_keyfile;
    Open_devices;
    Format_devices;
    Installation_initialize;
    Initramfs_top
  ]


exception Unknown_command of string

let command_of_string = function
  | "mount_key_device" -> Mount_key_device
  | "umount_key_device" -> Umount_key_device
  | "create_keyfile" -> Create_keyfile
  | "open_devices" -> Open_devices
  | "format_devices" -> Format_devices
  | "installation_initialize" -> Installation_initialize
  | "initramfs_top" -> Initramfs_top
  | cmd -> raise (Unknown_command cmd)

let string_of_command = function
  | Mount_key_device -> "mount_key_device"
  | Umount_key_device -> "umount_key_device"
  | Create_keyfile -> "create_keyfile"
  | Open_devices -> "open_devices"
  | Format_devices -> "format_devices"
  | Installation_initialize -> "installation_initialize"
  | Initramfs_top -> "initramfs_top"

let error_message () =
  "Expected exactly one of the following commands as argument: "
  ^ (commands |> List.map (string_of_command %> cyan) |> String.concat " | ") ^ "."

let get_key () =
  "Computing key." |> print_endline;
  let password = prompt_password () in
  wait_for_file "/keys/keyfile" timeout;
  let keyfile = "cat /keys/keyfile" |> as_root |> command_with_string_output in
  password_xor_keyfile password keyfile

let rec ocaml_cryptsetup = function
  | Mount_key_device -> mount keyfile_device "/keys" timeout
  | Umount_key_device -> umount "/keys" timeout
  | Create_keyfile ->
    "dd if=/dev/urandom of=/keys/keyfile bs=1024 count=1" |> as_root |> command;
    "chmod 0400 /keys/keyfile" |> as_root |> command
  | Open_devices ->
    let key = get_key () in
    encrypted_devices |> List.iter (fun (device, encrypted_device) ->
      "cryptsetup luksOpen --key-file - " ^ device ^ " " ^ encrypted_device
      |> as_root
      |> general_command (string_input_handler key) drop_output_handler stderr_handler
      |> ignore
    )
  | Format_devices ->
    let key = get_key () in
    encrypted_devices |> List.iter (fun (device, encrypted_device) ->
      "cryptsetup luksFormat --key-file - " ^ device ^ " " ^ encrypted_device
      |> as_root
      |> general_command (string_input_handler key) drop_output_handler stderr_handler
      |> ignore
    )
  | Installation_initialize ->
    [
      Mount_key_device;
      Create_keyfile;
      Format_devices;
      Open_devices;
      Umount_key_device
    ]
    |> List.iter ocaml_cryptsetup
  | Initramfs_top ->
    [
      Mount_key_device;
      Open_devices;
      Umount_key_device
    ]
    |> List.iter ocaml_cryptsetup

let _ =
  if Sys.argv |> Array.length <> 2 then
    error ^ " No argument given! " ^ error_message () |> prerr_endline
  else ();
  try
    Sys.argv.(1)
    |> command_of_string
    |> ocaml_cryptsetup
  with
  | Unknown_command cmd ->
    error ^ " Unknown command " ^ (cmd |> cyan) ^ "! " ^ error_message () |> prerr_endline
