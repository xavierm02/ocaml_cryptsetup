open Color2
open Unix

exception Command_failed of string

let string_of_status = function
  | WEXITED n -> "WEXITED " ^ (n |> string_of_int)
  | WSIGNALED n -> "WSIGNALED " ^ (n |> string_of_int)
  | WSTOPPED n -> "WSTOPPED " ^ (n |> string_of_int)

let string_of_char char =
  String.make 1 char

let string_of_in_channel channel =
  let string = ref "" in
  try
    while true do
      let char = input_char channel in
      string := !string ^ (string_of_char char)
    done;
    failwith "After while true!"
  with
  | End_of_file -> !string

let general_command stdin2 stdout2 stderr2 command =
  (command |> cyan) ^ " " |> print_string;
  flush_all ();
  let pid = Unix.create_process "/bin/sh" [|"/bin/sh"; "-c"; command|] stdin2 stdout2 stderr2 in
  let _, status = Unix.waitpid [] pid in
  match status with
  | WEXITED 0 ->
    ok |> print_endline
  | _ ->
    error ^ " " ^ (status |> string_of_status) |> prerr_endline;
    raise (Command_failed command)

let empty_stdin2 f =
  let stdin2_read, stdin2_write = Unix.pipe () in
  Unix.close stdin2_write;
  f stdin2_read;
  Unix.close stdin2_read

let string_stdout2 f =
  let stdout2_read, stdout2_write = Unix.pipe () in
  f stdout2_write;
  Unix.close stdout2_write;
  let result =
    stdout2_read
    |> Unix.in_channel_of_descr
    |> string_of_in_channel
  in
  Unix.close stdout2_read;
  result

let command command =
  string_stdout2 (fun stdout2_write ->
    empty_stdin2 (fun stdin2_read ->
      general_command stdin2_read stdout2_write Unix.stderr command
    )
  )

let command_with_stdin command =
  string_stdout2 (fun stdout2_write ->
    general_command Unix.stdin stdout2_write Unix.stderr command
  )
(*

let command command =
  (command |> cyan) ^ " " |> print_string;
  flush_all ();
  let stdout2, stdin2 = Unix.open_process command in
  let output = stdout2 |> string_of_in_channel in
  let status = close_process (stdout2, stdin2) in
  match status with
  | WEXITED 0 ->
    ok |> print_endline;
    output
  | _ ->
    error ^ (status |> string_of_status) |> prerr_endline;
    raise (Command_failed command)

    *)
(*
let exec_command ?(input = None) command =
  let stdout2, stdin2, stderr2 = Unix.open_process_full command [||] in
  let todo =
    match input with
    | None -> fun () -> ()
    | Some x ->
      let pid = Unix.fork () in
      if pid = 0 then begin
        IO.copy x stdin2;
        exit 0
      end else begin
        fun () ->
          Unix.waitpid [] pid |> ignore
      end
  in
  IO.close_out stdin2;
  let output_messages = stdout2 |> IO.read_all in
  let error_messages = stderr2 |> IO.read_all in
  todo ();
  if Unix.close_process_full (stdout2, stdin2, stderr2) = Unix.WEXITED 0 then
    Result output_messages
  else
    Error_message error_messages

let exec_simple_command command =
  let return_code = Sys.command command in
  if return_code = 0 then
    Result ()
  else
    Error_message ("Command " ^ (command |> cyan) ^ " returned " ^ (return_code |> string_of_int |> cyan) ^ "!")

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

let verbose_simple_command command =
  verbose_do
    (command |> cyan)
    (fun () -> exec_simple_command command)

let silent_simple_command command =
  silent_do
    (command |> cyan)
    (fun () -> exec_simple_command command)
*)
