open Utils
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

let command_helper stdin2 stdout2 stderr2 command =
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

type 'o file_descr_handler = unit -> (file_descr * (unit -> 'o))

let empty_input_handler : unit file_descr_handler = fun () ->
  let input_read, input_write = Unix.pipe () in
  Unix.close input_write;
  let close () =
    Unix.close input_read
  in
  input_read, close

let string_input_handler string : unit file_descr_handler = fun () ->
  let input_read, input_write = Unix.pipe () in
  let oc = Unix.out_channel_of_descr input_write in
  for i = 0 to String.length string - 1 do
    output_char oc string.[i]
  done;
  Unix.close input_write;
  let close () =
    Unix.close input_read
  in
  input_read, close

let drop_output_handler : unit file_descr_handler = fun () ->
  let output_read, output_write = Unix.pipe () in
  let close () =
    Unix.close output_write;
    Unix.close output_read
  in
  output_write, close

let string_output_handler : string file_descr_handler = fun () ->
  let output_read, output_write = Unix.pipe () in
  let close () =
    Unix.close output_write;
    let result =
      output_read
      |> Unix.in_channel_of_descr
      |> string_of_in_channel
    in
    Unix.close output_read;
    result
  in
  output_write, close

let descr_handler_of_descr descr = fun () -> (descr, fun () -> ())

let stdin_handler = descr_handler_of_descr Unix.stdin
let stdout_handler = descr_handler_of_descr Unix.stdout
let stderr_handler = descr_handler_of_descr Unix.stderr

let general_command input_handler output_handler error_handler cmd =
  let stdin2, close_stdin2 = input_handler () in
  let stdout2, close_stdout2 = output_handler () in
  let stderr2, close_stderr2 = error_handler () in
  command_helper stdin2 stdout2 stderr2 cmd;
  (close_stdin2 ()), (close_stdout2 ()), (close_stderr2 ())

let proj_3_2 (_, x, _) = x

let command cmd =
  general_command empty_input_handler drop_output_handler stderr_handler cmd |> ignore

let command_with_stdin cmd =
  general_command stdin_handler drop_output_handler stderr_handler cmd |> ignore

let command_with_string_output cmd =
  let _, result, _ = general_command empty_input_handler string_output_handler stderr_handler cmd in
  result

let as_root =
  let f = ref None in
  let update_f () =
    try
      if Unix.geteuid () = 0 then begin
        ok ^ " The user is " ^ ("root" |> cyan) ^ "." |> print_endline;
        f := Some (fun cmd -> cmd);
        raise Done
      end else begin
        info ^ " The user is not " ^ ("root" |> cyan) ^ "." |> print_endline
      end;
      begin
        try
          command "which sudo" |> ignore;
          ok ^ " " ^ ("sudo" |> cyan) ^ " is available." |> print_endline;
          f := Some (fun cmd -> "sudo " ^ cmd);
          raise Done
        with
        | Command_failed _ ->
          info ^ " " ^ ("sudo" |> cyan) ^ " is not available." |> print_endline;
      end;
      begin
        try
          command "which su" |> ignore;
          ok ^ " " ^ ("su" |> cyan) ^ " is available." |> print_endline;
          f := Some (fun cmd -> "su -c " ^ cmd);
          raise Done
        with
        | Command_failed _ ->
          info ^ " " ^ ("su" |> cyan) ^ " is not available." |> print_endline;
      end;
      error ^ " Could not find a way to run a command as root!" |> prerr_endline;
      failwith "Could not find a way to run a command as root!"
    with
    | Done -> ()
  in
  let rec _as_root cmd =
    "Trying to find a way to run " ^ (cmd |> cyan) ^ " as root..." |> print_endline;
    begin
      match !f with
      | None -> update_f ()
      | _ -> ()
    end;
    match !f with
    | None -> failwith "update_f didn't update f!"
    | Some g ->
      let new_cmd = g cmd in
      ok ^ " The new command is " ^ (new_cmd |> cyan) ^ "." |> print_endline;
      new_cmd
  in _as_root
