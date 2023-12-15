open! Core

let ( <| ) f g x = f (g x)
let write_to_file ~path content = Eio.Path.save ~create:(`Or_truncate 0o600) path content
let read_file ~path = Eio.Path.load path

(**
  Accepts two parsers p and q that return strings and returns a new
  parser that matches both p and q consecutively and concatenates their
  outcome.
*)
let ( <^> ) p q = Angstrom.(( ^ ) <$> p <*> q)

(**
  Accepts two parsers p and q and returns a new parser that matches
  both p and q consecutively and returns their results in a pair.
*)
let ( <&> ) p q = Angstrom.((fun s r -> s, r) <$> p <*> q)
