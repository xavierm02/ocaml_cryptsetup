open Batteries
open Color2
open Conf
open Xor
open Command
open File_utils

let disable_echo () =
  silent_simple_command("stty -echo")

let enable_echo () =
  silent_simple_command("stty echo")

let prompt_password () : string =
  let stty_present = check_file_exists "/bin/stty" in
  if not stty_present then
    info (("stty" |> cyan) ^ " is not present on the system so the password will not be hidden.")
  else ();
  print_string "Password: ";
  IO.flush IO.stdout;
  if stty_present then begin
    Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> enable_echo (); error "Interrupted."));
    disable_echo ();
  end else ();
  let password = read_line () in
  if stty_present then begin
    enable_echo ();
    Sys.set_signal Sys.sigint Sys.Signal_default;
    print_newline ()
  end else ();
  password

let fixed_combine (a,b) =
  IO.wrap_out ~write:(fun c ->
    IO.write a c;
    IO.write b c)
    ~output:(fun s i j ->
      let _ = IO.output a s i j in
      IO.output b s i j)
    ~flush:(fun () ->
      IO.flush a;
      IO.flush b)
    ~close:(fun () -> ()) (* Removed close_out calls *)
    ~underlying:[IO.cast_output a; IO.cast_output b]

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
