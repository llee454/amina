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
         let* root = read_file ~filename:data_filename >|= Yojson.Safe.from_string in
         Stack.push Rewrite.json_context_stack root;
         let* template = read_file ~filename:template_filename in
         let () = [%sexp_of: Json.t] root |> Guile.Sexp.to_raw |> Guile.Module.define "root" in
         let _res =
           Angstrom.parse_string ~consume:All Rewrite.parse template |> function
           | Result.Error _ -> failwith "Error: an error occured while trying to parse the template file."
           | Result.Ok parsing -> Rewrite.rewrite parsing |> printf "Result: %s\n"
         in
         Lwt.return_unit
     end
