open! Core
open! Amina
open! Getopt
open! Aux

let scheme_filename_opt = ref None
let data_filename_opt = ref None
let template_filename_opt = ref None

let specs =
  [
    ( 'v',
      "version",
      Some
        (fun () ->
          printf "Amina version 0.7.0\n";
          exit 0),
      None );
    ( 'h',
      "help",
      Some
        (fun () ->
          printf "%s\n" [%blob "help.md"];
          exit 0),
      None );
    's', "init", None, Some (fun x -> scheme_filename_opt := Some x);
    'd', "json", None, Some (fun x -> data_filename_opt := Some x);
    't', "template", None, Some (fun x -> template_filename_opt := Some x);
  ]

let () =
  Eio_main.run @@ fun env ->
  let fs = Eio.Stdenv.fs env in
  parse_cmdline specs (Fn.const ());
  match !template_filename_opt with
  | None -> failwith "Error: Invalid command line. The template file is required."
  | Some template_filename ->
    let root =
      begin
        match !data_filename_opt with
        | None -> Eio.Flow.read_all (Eio.Stdenv.stdin env)
        | Some data_filename -> Aux.read_file ~path:Eio.Path.(fs / data_filename)
      end
      |> Yojson.Safe.from_string
    in
    Scheme.init ();
    Option.iter !scheme_filename_opt ~f:(fun filename ->
        let _ = Guile.load filename in
        ()
    );
    let template = Aux.read_file ~path:Eio.Path.(fs / template_filename) in
    Rewrite.init_contexts root;
    Eio.Flow.copy_string (Rewrite.rewrite_string template) (Eio.Stdenv.stdout env)
