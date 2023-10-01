open! Core
open! Lwt.Syntax
open! Lwt.Infix
open! Lib
open! Getopt
open! Aux

let data_filename_opt = ref None
let template_filename_opt = ref None
let specs = [ 'd', "json", None, Some (fun x -> data_filename_opt := Some x) ]

let () =
  Lwt_main.run
  @@ begin
       parse_cmdline specs (fun x -> template_filename_opt := Some x);
       match !data_filename_opt, !template_filename_opt with
       | None, _ -> failwith "Error: Invalid command line. The data file is required."
       | _, None -> failwith "Error: Invalid command line. The template file is required."
       | Some data_filename, Some template_filename ->
         Guile.init ();
         let _ =
           let open Guile in
           Functions.register_fun1 "get-data" (fun (path : scm) ->
               if String.is_string path
               then
                 String.from_raw path
                 |> Path.eval_string ~root:(Rewrite.get_root_json_context ())
                      ~local:(Rewrite.get_local_json_context ())
                 |> [%sexp_of: Json.t]
                 |> Guile.Sexp.to_raw
               else
                 Error.error ~fn_name:"get-data"
                   "Error: an error occured while trying to evaluate a call to get-data. get-data \
                    expects a single string argument that represents a JSON path expression."
           )
         in
         let* root = read_file ~filename:data_filename >|= Yojson.Safe.from_string in
         let* template = read_file ~filename:template_filename in
         Rewrite.init_contexts root;
         Rewrite.rewrite_string template |> printf "%s";
         Lwt.return_unit
     end
