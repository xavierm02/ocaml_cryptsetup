open Batteries
open Color

let red = color Red
let green = color Green
let yellow = color Yellow
let blue = color Blue
let cyan = color Cyan

exception Error of string

let ok message =
  ("[OK]" |> green) ^ " " ^ message |> prerr_endline

let info message =
  ("[INFO]" |> blue) ^ " " ^ message |> prerr_endline

let warning message =
  ("[WARNING]" |> yellow) ^ " " ^ message |> prerr_endline

let error message =
  raise (Error (("[ERROR]" |> red) ^ " " ^ message))

let show_errors f =
  try
    f ()
  with
  | Error message -> message |> prerr_endline

type 'a result =
  | Result of 'a
  | Error_message of string

let verbose_do message f =
  prerr_string (message ^ " ");
  IO.flush IO.stderr;
  match f () with
  | Result result ->
    prerr_endline ("[OK]" |> green);
    result
  | Error_message error ->
    prerr_endline ("[ERROR]" |> red);
    raise (Error error)

let silent_do message f =
  match f () with
  | Result result -> result
  | Error_message error ->
    prerr_endline (message ^ " " ^ ("[ERROR]" |> red));
    raise (Error error)
