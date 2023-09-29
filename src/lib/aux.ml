open! Core
open! Lwt.Syntax
open! Lwt.Infix

let ( <| ) f g x = f (g x)

let overwrite_flags = Lwt_unix.[ O_WRONLY; O_NONBLOCK; O_CREAT; O_TRUNC ]

let read_flags = Lwt_unix.[ O_RDONLY; O_NONBLOCK ]

let write_to_file ~filename content =
  Lwt_io.with_file ~flags:overwrite_flags ~mode:Output filename (fun oc -> Lwt_io.fprint oc content)

let read_file ~filename =
  Lwt_io.with_file ~flags:read_flags ~mode:Input filename (fun ic -> Lwt_io.read ic)
