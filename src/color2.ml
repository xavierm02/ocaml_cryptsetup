open Utils

let red s = "\027[31m" ^ s ^ "\027[0m"
let green s = "\027[32m" ^ s ^ "\027[0m"
let yellow s = "\027[33m" ^ s ^ "\027[0m"
let blue s = "\027[34m" ^ s ^ "\027[0m"
let cyan s = "\027[36m" ^ s ^ "\027[0m"
let white s = "\027[37m" ^ s ^ "\027[0m"

exception Error of string

let ok =
  "[OK]" |> green

let info =
  "[INFO]" |> blue

let warning =
  "[WARNING]" |> yellow

let error =
  "[ERROR]" |> red
