open! Core
open! Lwt.Syntax
open! Lwt.Infix

let debug_mode = ref false
let ( <| ) f g x = f (g x)
let overwrite_flags = Lwt_unix.[ O_WRONLY; O_NONBLOCK; O_CREAT; O_TRUNC ]
let read_flags = Lwt_unix.[ O_RDONLY; O_NONBLOCK ]

let write_to_file ~filename content =
  Lwt_io.with_file ~flags:overwrite_flags ~mode:Output filename (fun oc -> Lwt_io.fprint oc content)

let read_file ~filename =
  Lwt_io.with_file ~flags:read_flags ~mode:Input filename (fun ic -> Lwt_io.read ic)

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
