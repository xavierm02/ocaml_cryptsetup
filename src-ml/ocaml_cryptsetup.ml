open Batteries
open Color2
open Conf
open Xor
open Command


let wait_timeout file timeout =
  verbose_do
    ("Waiting for " ^ (file |> cyan) ^ " for " ^ (timeout |> string_of_int |> cyan) ^ " seconds...")
    (fun () ->
      let timeout_float = timeout |> float_of_int in
      let start_time = Unix.time () in
      let rec aux () =
        if Sys.file_exists file then
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

let prompt_password () =
  print_string "Password: ";
  IO.flush IO.stdout;
  silent_simple_command("stty -echo");
  let password = read_line () in
  silent_simple_command("stty echo");
  print_newline ();
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
  | Mount_keys -> verbose_command ("mount " ^ (key_file_device |> file_of_device) ^ " /keys") |> ignore
  | Umount_keys -> verbose_command "umount /keys" |> ignore
  | Create_key_file ->
    verbose_simple_command "dd if=/dev/urandom of=/keys/keyfile bs=1 count=32";
	  verbose_simple_command "chmod 0400 /keys/keyfile"
  | Open_devices -> cryptsetups (fun device -> "cryptsetup luksOpen --key-file - " ^ (device |> file_of_device) ^ " " ^ (device |> label_of_device) ^ "_crypt")
  | Format_devices -> cryptsetups (fun device -> "cryptsetup luksFormat --key-file - " ^ (device |> file_of_device))
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
      Sys.argv.(1)
      |> command_of_string
      |> ocaml_cryptsetup
    with
    | Unknown_command command -> error ("Unknown command " ^ (command |> cyan) ^ "!")
  )
