open Color

let red = color Red
let green = color Green
let yellow = color Yellow
let blue = color Blue
let cyan = color Cyan

let ok message =
  ("[OK]" |> green) ^ " " ^ message |> print_endline

let info message =
  ("[INFO]" |> blue) ^ " " ^ message |> print_endline

let warning message =
  ("[WARNING]" |> yellow) ^ " " ^ message |> print_endline

let error message =
  ("[ERROR]" |> red) ^ " " ^ message |> print_endline;
  exit 1
