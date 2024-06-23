open! Core
open! Lwt.Syntax
open! Lwt.Infix
open! Getopt
open! Amina
open! Aux
open! Amina_guile

let scheme_filename_opt = ref None
let no_data = ref false
let data_filename_opt = ref None
let template_filename_opt = ref None

let specs =
  [
    ( 'v',
      "version",
      Some
        (fun () ->
          printf "Amina version 0.15.0\n";
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
    'x', "debug", Some (fun () -> debug_mode := true), None;
    'w', "warn", Some (fun () -> warn_mode := true), None;
    'n', "no-json", Some (fun () -> no_data := true), None;
  ]

let () =
  Lwt_main.run
  @@ begin
       parse_cmdline specs (Fn.const ());
       match !template_filename_opt with
       | None -> failwith "Error: Invalid command line. The template file is required."
       | Some template_filename ->
         let* root =
           if !no_data
           then Lwt.return `Null
           else
             begin
               match !data_filename_opt with
               | None -> Lwt_io.read Lwt_io.stdin
               | Some data_filename -> read_file ~filename:data_filename
             end
             >|= Yojson.Basic.from_string
         in
         init_guile ();
         Scheme.init ();
         Rewrite.init_contexts root;
         Option.iter !scheme_filename_opt ~f:(fun filename ->
             let _ = load filename in
             ()
         );
         let* template = read_file ~filename:template_filename in
         Rewrite.rewrite_string template |> printf "%s";
         Lwt.return_unit
     end
