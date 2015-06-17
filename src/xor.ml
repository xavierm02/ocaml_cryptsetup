open Utils
open Color2

exception Done
(*
let read_byte_option input =
  try
    Some (IO.read_byte input)
  with
  | IO.No_more_input -> None

let password_xor_key_to_output password_input key_input output =
  try
    while true do
      match read_byte_option password_input, read_byte_option key_input with
      | None, None -> raise Done
      | None, Some key_byte -> key_byte |> IO.write_byte output
      | Some _, None -> error "The key is too short!"
      | Some password_byte, Some key_byte -> password_byte lxor key_byte |> IO.write_byte output
    done
  with
  | Done -> ()
*)
