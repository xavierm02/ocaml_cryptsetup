open Batteries
open Color2
open Conf
open Xor
open Command
open File_utils

let prompt_password () =
  print_string "Password: ";
  IO.flush IO.stdout;
  let could_hide =
    try
      silent_simple_command("stty -echo");
      true
    with
    | Error _ -> false
  in
  if not could_hide then
    warning (("stty -echo" |> cyan) ^ " caused an error. You can continue using this program but the password you type will be shown.")
  else ();
  let password = read_line () in
  if could_hide then begin
    silent_simple_command("stty echo");
    print_newline ()
  end else ();
  password

let cryptsetups make_command =
  let pipes_read, pipes_write =
    encrypted_devices
    |> List.map (ignore %> IO.pipe)
    |> List.split
  in
  let all_pipes_write =
    pipes_write |> List.fold_left
      (fun x y -> IO.combine (x, y |> IO.cast_output) |> IO.cast_output)
      IO.stdnull
  in
  let password = prompt_password () in
  File.with_file_in "/keys/key_file" (fun key_input ->
    password_xor_key_to_output
      (password |> IO.input_string)
      key_input
      all_pipes_write
  );
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

let rec ocaml_cryptsetup = function
  | Mount_keys -> mount key_file_device "/keys" timeout
  | Umount_keys -> umount "/keys" timeout
  | Create_key_file ->
    verbose_simple_command "dd if=/dev/urandom of=/keys/key_file bs=1M count=32";
	  verbose_simple_command "chmod 0400 /keys/key_file"
  | Open_devices -> cryptsetups (fun (device, name) -> "cryptsetup luksOpen --key-file - " ^ device ^ " " ^ name)
  | Format_devices -> cryptsetups (fun (device, _) -> "cryptsetup luksFormat --key-file - " ^ device)
  | Installation_initialize ->
    [
      Mount_keys;
      Create_key_file;
      Format_devices;
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

let _ =
  show_errors (fun () ->
    if Sys.argv |> Array.length <> 2 then
      error "Expected exactly one argument."
    else ();
    try
      prompt_password () |> ignore;
      Sys.argv.(1)
      |> command_of_string
      |> ocaml_cryptsetup
    with
    | Unknown_command command -> error ("Unknown command " ^ (command |> cyan) ^ "!")
  )
