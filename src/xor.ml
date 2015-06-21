open Utils
open Color2

let string_of_char c = String.make 1 c

let char_lxor c1 c2 =
  let i1 = int_of_char c1 in
  let i2 = int_of_char c2 in
  let i3 = i1 lxor i2 in
  let c3 = char_of_int i3 in
  c3

let password_xor_keyfile password keyfile =
  let password_length = String.length password in
  let keyfile_length = String.length keyfile in
  if password_length > keyfile_length then
    failwith "The password is longer than the keyfile!"
  else ();
  let result = ref "" in
  for i = 0 to password_length - 1 do
    result := !result ^ (char_lxor password.[i] keyfile.[i] |> string_of_char)
  done;
  for i = password_length to keyfile_length - 1 do
    result := !result ^ (keyfile.[i] |> string_of_char)
  done;
  !result
