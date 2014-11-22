open Batteries
open Color2

let exec_command ?(input = None) command =
  let stdout2, stdin2, stderr2 = Unix.open_process_full command [||] in
  begin
    match input with
    | None -> ()
    | Some x -> IO.copy x stdin2
  end;
  IO.close_out stdin2;
  let output_messages = stdout2 |> IO.read_all in
  let error_messages = stderr2 |> IO.read_all in
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

