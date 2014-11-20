open Batteries
open Color2
open Conf
open Xor

let exec_command ?(input = None) command =
  let stdout2, stdin2, stderr2 = Unix.open_process_full command [||] in
  begin
    match input with
    | None -> ()
    | Some x -> IO.copy x stdin2
  end;
  IO.close_out stdin2;
  let error_messages = stderr2 |> IO.read_all in
  if Unix.close_process_full (stdout2, stdin2, stderr2) = Unix.WEXITED 0 then
    None
  else
    Some error_messages

let exec_simple_command command =
  let return_code = Sys.command command in
  if return_code = 0 then
    None
  else
    Some ("Command " ^ (command |> cyan) ^ " returned " ^ (return_code |> string_of_int |> cyan) ^ "!")

let verbose_command ?(input = None) command =
  verbose_do
    (command |> cyan)
    (fun () ->
      exec_command
      ~input:input
      command
    )

let silent_command ?(input = None) command =
  silent_do
    (command |> cyan)
    (fun () ->
      exec_command
      ~input:input
      command
    )

let silent_simple_command command =
  silent_do
    (command |> cyan)
    (fun () -> exec_simple_command command)

let wait_timeout file timeout =
  verbose_do
    ("Waiting for " ^ (file |> cyan) ^ " for " ^ (timeout |> string_of_int |> cyan) ^ " seconds...")
    (fun () ->
      let timeout_float = timeout |> float_of_int in
      let start_time = Unix.time () in
      let rec aux () =
        if Sys.file_exists file then
          None
        else if Unix.time () -. start_time >= timeout_float then
          Some "Timeout!"
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
  )

exception Unknown_command

let rec ocaml_cryptsetup = function
  | "mount_keys" -> verbose_command ("mount " ^ key_file_device ^ " /keys")
  | "umount_keys" -> verbose_command "umount /keys"
  | "create_key_file" ->
    verbose_command "dd if=/dev/urandom of=/keys/keyfile bs=1 count=32";
	  verbose_command "chmod 0400 /keys/keyfile"
  | "open_devices" -> cryptsetups (fun device -> "cryptsetup luksOpen --key-file - " ^ device ^ " " ^ device ^ "_crypt")
  | "format_devices" -> cryptsetups (fun device -> "cryptsetup luksFormat --key-file - " ^ device)
  | "test" -> verbose_command ~input:(Some (IO.input_string "test")) "cat"
  | _ -> raise Unknown_command

let _ =
  show_errors (fun () ->
    if Sys.argv |> Array.length <> 2 then
      error "Expected exactly one argument."
    else ();
    let command = Sys.argv.(1) in
    try
      ocaml_cryptsetup command
    with
    | Unknown_command -> error ("Unknown command " ^ (command |> cyan) ^ "!")
  )
























