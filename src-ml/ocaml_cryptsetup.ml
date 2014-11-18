open Batteries
open Color2
open Xor
open File_utils

let fork_do ~child ~child_input ~child_output =
  let pid = Unix.fork () in
  if pid = 0 then begin
    Unix.dup2 child_input Unix.stdin;
    Unix.dup2 child_output Unix.stdout;
    child ();
    exit 0
  end else begin
    pid
  end

let cryptsetup key_file arguments_list =
  let key_file = "xor.ml" in
  let password = IO.read_line IO.stdin in
  let xor_pid, xor_output =
    let pipe_read, pipe_write = Unix.pipe () in
    let pid = Unix.fork () in
    if pid = 0 then begin
      Unix.close pipe_read;
      File.with_file_in key_file (fun key_input ->
        password_xor_key_to_output
          (password |> IO.input_string)
          key_input
          (pipe_write |> Unix.output_of_descr)
      );
      exit 0
    end else begin
      Unix.close pipe_write;
      (pid, (Unix.input_of_descr pipe_read))
    end
  in
  let cryptsetup_pids, cryptsetup_inputs =
    arguments_list
    |> List.map (fun arguments ->
      let pipe_read, pipe_write = Unix.pipe () in
      let pid = Unix.fork () in
      if pid = 0 then begin
        Unix.close pipe_write;
        Unix.dup2 pipe_read Unix.stdin;
        Unix.execvp "cat" ("cat" :: arguments |> Array.of_list)
      end else begin
        Unix.close pipe_read;
        (pid, pipe_write |> Unix.output_of_descr)
      end
    )
    |> List.split
  in
  cryptsetup_inputs
  |> List.fold_left
    (fun x y -> IO.combine (x, y |> IO.cast_output) |> IO.cast_output)
    IO.stdnull
  |> IO.copy xor_output

let _ =
  if Array.length Sys.argv <> 2 then
    error "Exactly one argument is expected!"
  else ();
  match Sys.argv.(1) with
  | "qwe" -> begin
    cryptsetup "xor.ml" [[]; []]
  end
  | s -> error ("Unknown command " ^ (s |> cyan) ^ ".")

