let (|>) x f = f x

let (%>) f g x =
  x |> f |> g

exception Done
