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
  ( 'd', "json", None, Some (fun x -> data_filename_opt := Some x));
]

let json_context_stack = Stack.create ()

let parse_scheme_tag =
  let open Angstrom in
  (string "{expr:" *> take_till (Char.equal '}') <* char '}') >>| (fun s ->
    let open Guile in
    match eval_string s with
    | x when String.is_string x -> String.from_raw x
    | x -> Guile.to_string x
  )

let parse_path_tag =
  let open Angstrom in
  (char '{' *> take_till (Char.equal '}') <* char '}') >>| (fun path ->
  let json_context = Stack.top_exn json_context_stack in
  match Angstrom.parse_string ~consume:All Path.parse_path path with
  | Error msg -> failwithf "Error: an error occured while trying to handle a JSON path. %s" msg ()
  | Ok parser -> parser json_context |> Yojson.Safe.pretty_to_string
  )

let parse_template =
  let open Angstrom in
  (^) <$> (many ((^) <$> (take_till (Char.equal '{')) <*> (parse_scheme_tag <|> parse_path_tag)) >>| String.concat) <*> (take_while (Fn.const true))

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
      Stack.push json_context_stack root;
      let* template = read_file ~filename:template_filename in
      let () = [%sexp_of: Json.t] root |> Guile.Sexp.to_raw |> Guile.Module.define "root" in
      let _res = Angstrom.parse_string ~consume:All parse_template template |> function
      | Result.Error _ -> failwith "Error: an error occured while trying to parse the template file."
      | Result.Ok result ->
        printf "Result: %s\n" result
      in
      Lwt.return_unit
  end
