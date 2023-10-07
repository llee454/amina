open! Core
open! Lwt.Syntax
open! Lwt.Infix
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
          printf "Amina version 0.6.0\n";
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
  Lwt_main.run
  @@
  begin
    parse_cmdline specs (Fn.const ());
    match !template_filename_opt with
    | None -> failwith "Error: Invalid command line. The template file is required."
    | Some template_filename ->
      let* root =
        begin
          match !data_filename_opt with
          | None -> Lwt_io.read Lwt_io.stdin
          | Some data_filename -> read_file ~filename:data_filename
        end
        >|= Yojson.Safe.from_string
      in
      Scheme.init ();
      Option.iter !scheme_filename_opt ~f:(fun filename ->
          let _ = Guile.load filename in
          ());
      let* template = read_file ~filename:template_filename in
      Rewrite.init_contexts root;
      Rewrite.rewrite_string template |> printf "%s";
      Lwt.return_unit
  end
