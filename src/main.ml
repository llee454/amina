open! Core
open! Lwt.Syntax
open! Lwt.Infix
open! Lib
open! Getopt
open! Aux

let data_filename_opt = ref None
let template_filename_opt = ref None

let specs =
  [
    ( 'v',
      "version",
      Some
        (fun () ->
          printf "Amina version 0.1.0\n";
          exit 0),
      None );
    ( 'h',
      "help",
      Some
        (fun () ->
          printf "%s\n" [%blob "help.md"];
          exit 0),
      None );
    'd', "json", None, Some (fun x -> data_filename_opt := Some x);
    't', "template", None, Some (fun x -> template_filename_opt := Some x);
  ]

let () =
  Lwt_main.run
  @@ begin
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
         let* template = read_file ~filename:template_filename in
         Rewrite.init_contexts root;
         Rewrite.rewrite_string template |> printf "%s";
         Lwt.return_unit
     end
