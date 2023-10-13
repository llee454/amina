(*
  TODO:
  - [ ] allow white space in expressions
  - [ ] allow escaping braces
*)

open! Core
open! Angstrom
open! Aux

type tag_type =
  | Expr_tag
  | Data_tag
  | Each_tag
  | Each_expr_tag
[@@deriving equal, sexp]

let tag_type_of_string = function
| "expr" -> Expr_tag
| "data" -> Data_tag
| "each" -> Each_tag
| "each-expr" -> Each_expr_tag
| s -> failwithf "Error: \"%s\" is an invalid tag name." s ()

let tag_type_to_string = function
| Expr_tag -> "expr"
| Data_tag -> "data"
| Each_tag -> "each"
| Each_expr_tag -> "each-expr"

let root_json_context = ref None

let get_root_json_context () : Yojson.Safe.t =
  match !root_json_context with
  | None ->
    failwith
      "Error: an internal error occured. You probabily tried to evaluate a JSON path without first \
       setting the root JSON context."
  | Some json -> json

let json_context_stack = Stack.create ()

let get_local_json_context () : Yojson.Safe.t =
  match Stack.top json_context_stack with
  | None ->
    failwith
      "Error: an internal error occured. You probabily tried to evaluate a JSON path without first \
       setting the local JSON context."
  | Some json -> json

(**
  Initializes the evaluation contexts. You must call this function
  before you call the evluation functions defined in this module.
*)
let init_contexts json =
  root_json_context := Some json;
  Stack.push json_context_stack json

let tag_stack = Stack.create ()

(**
  Represents the grammar of template files.
*)
type grammar =
  | Text of string
  | Tag of tag_type * string
  | Section of tag_type * string * grammar list
[@@deriving sexp]

let is_open_brace = Char.equal '{'

let is_close_brace = Char.equal '}'

let is_pound = Char.equal '#'

let is_slash = Char.equal '/'

let is_backslash = Char.equal '\\'

let is_colon = Char.equal ':'

let lex_open_brace = string "{"

let lex_close_brace = string "}"

let lex_colon = string ":"

let lex_pound = string "#"

let lex_slash = string "/"

let lex_backslash = string "\\"

let parse_escaped_char = lex_backslash *> any_char >>| String.of_char

let%expect_test "parse_text" =
  {|\{|}
  |> Angstrom.parse_string ~consume:Prefix parse_escaped_char
  |> Result.ok_or_failwith
  |> printf "%s";
  [%expect {| { |}]

let parse_text =
  many1 (parse_escaped_char <|> take_while1 (fun c -> (not (is_open_brace c)) && not (is_backslash c)))
  >>| fun xs -> Text (String.concat xs)

let%expect_test "parse_text" =
  {|This is a test. \{not a tag\\} {expr: 55}|}
  |> Angstrom.parse_string ~consume:Prefix parse_text
  |> Result.ok_or_failwith
  |> printf !"%{sexp: grammar}";
  [%expect {| (Text "This is a test. {not a tag\\} ") |}]

let parse_tag_name =
  take_while1 (fun c ->
      (not (is_colon c)) && (not (is_pound c)) && (not (is_slash c)) && not (is_close_brace c))
  >>| tag_type_of_string

let parse_tag_content = take_till is_close_brace

let parse_tag =
  lex_open_brace *> parse_tag_name <&> lex_colon *> parse_tag_content <* lex_close_brace >>| fun (t, s) ->
  Tag (t, s)

let%expect_test "parse_tag" =
  "{expr: 55}"
  |> Angstrom.parse_string ~consume:All parse_tag
  |> Result.ok_or_failwith
  |> printf !"%{sexp: grammar}";
  [%expect {| (Tag Expr_tag " 55") |}]

let parse_open_section_tag =
  lex_open_brace *> lex_pound *> parse_tag_name <&> lex_colon *> parse_tag_content <* lex_close_brace
  >>| fun (tag, s) ->
  Stack.push tag_stack tag;
  tag, s

let parse_close_section_tag =
  lex_open_brace *> lex_slash *> parse_tag_name <* lex_close_brace >>| fun tag ->
  match Stack.pop tag_stack with
  | Some curr_tag when [%equal: tag_type] curr_tag tag -> ()
  | Some curr_tag ->
    failwithf "Error: invalid close section tag. We expected you to close the \"%s\" tag first."
      (tag_type_to_string curr_tag) ()
  | None -> failwithf "Error: invalid close section tag. You need to open a section first." ()

let parse =
  fix (fun recurse ->
      many
        (parse_text
        <|> parse_tag
        <|> ( parse_open_section_tag <&> recurse <* parse_close_section_tag
            >>| fun ((tag, expr), content) -> Section (tag, expr, content) )
        ))

let parse_string (template : string) =
  Angstrom.parse_string ~consume:All parse template |> function
  | Error msg -> failwithf "Error: an error occured while trying to parse a template. %s" msg ()
  | Ok parsing -> parsing

let%expect_test "parse" =
  {json|
    {
      "example_array": [1, 2, 3]
    }
  |json}
  |> Yojson.Safe.from_string
  |> Stack.push json_context_stack;
  "This is an expression {expr: (* 3 7)} and this is a section {#each: .example_array}That has a nested \
   tag: {data: .}{/each}"
  |> Angstrom.parse_string ~consume:All parse
  |> Result.ok_or_failwith
  |> printf !"%{sexp: grammar list}";
  [%expect
    {|
    ((Text "This is an expression ") (Tag Expr_tag " (* 3 7)")
     (Text " and this is a section ")
     (Section Each_tag " .example_array"
      ((Text "That has a nested tag: ") (Tag Data_tag " .")))) |}]

let rewrite_text s = s

let rewrite_expr_tag expr =
  let open Guile in
  (match eval_string expr with x when String.is_string x -> String.from_raw x | x -> Guile.to_string x)

let rewrite_data_tag expr =
  Path.eval_string ~root:(get_root_json_context ()) ~local:(get_local_json_context ()) expr |> function
  | `Null -> ""
  | `String string -> string
  | json -> Yojson.Safe.pretty_to_string json

let rewrite_tag = function
| Expr_tag -> rewrite_expr_tag
| Data_tag -> rewrite_data_tag
| Each_tag -> failwith "Error: \"each\" tags can only open sections."
| Each_expr_tag -> failwith "Error: \"each\" tags can only open sections."

let rec rewrite_section = function
| Expr_tag -> failwith "Error: you have an \"expr\" tag opening a section."
| Data_tag -> failwith "Error: you have a \"data\" tag opening a section."
| Each_tag -> rewrite_each_section
| Each_expr_tag -> rewrite_each_expr_section

and rewrite_each_section expr content =
  match Path.eval_string ~root:(get_root_json_context ()) ~local:(get_local_json_context ()) expr with
  | `List xs | `Tuple xs ->
    List.map xs ~f:(fun next_json_context ->
        Stack.push json_context_stack next_json_context;
        let result = rewrite content in
        let _ = Stack.pop_exn json_context_stack in
        result)
    |> String.concat
  | x ->
    Stack.push json_context_stack x;
    let result = rewrite content in
    let _ = Stack.pop_exn json_context_stack in
    result

and rewrite_each_expr_section expr content =
  Guile.eval_string expr |> Json.of_scm |> function
  | `List xs | `Tuple xs ->
    List.map xs ~f:(fun next_json_context ->
        Stack.push json_context_stack next_json_context;
        let result = rewrite content in
        let _ = Stack.pop_exn json_context_stack in
        result)
    |> String.concat
  | x ->
    Stack.push json_context_stack x;
    let result = rewrite content in
    let _ = Stack.pop_exn json_context_stack in
    result

and rewrite content =
  List.map content ~f:(function
    | Text text -> rewrite_text text
    | Tag (tag, expr) -> rewrite_tag tag expr
    | Section (tag, expr, content) -> rewrite_section tag expr content)
  |> String.concat

(** Accepts a template string and expands the tags contained within it. *)
let rewrite_string template =
  try parse_string template |> rewrite with
  | Failure msg ->
    failwithf !"Error: an error occured while trying to parse and/or rewrite a template. %s" msg ()
  | _ ->
    failwithf
      !"Error: an error occured while trying to parse and/or rewrite a template. Perhaps you have an \
        unclosed section tag. The last opened section tag was (\"%{sexp: tag_type option}\")."
      (Stack.top tag_stack) ()

let%expect_test "rewrite" =
  Guile.init ();
  let root =
    {json|
     {
       "example_scalar": 3.14159,
       "example_array": [1, 2, 3]
     }
   |json}
    |> Yojson.Safe.from_string
  in
  init_contexts root;
  "This is a test expression {expr: (* 3 7)}. Here's a data {data:root.example_array[1]}. Here's a \
   section {#each:root.example_array}Item:{data:local} {/each}. It works! See?\n\
   Here's a scalar test {#each:root.example_scalar}value: {data:local}{/each}."
  |> rewrite_string
  |> printf "%s";
  [%expect
    {|
      This is a test expression 21. Here's a data 2. Here's a section Item:1 Item:2 Item:3 . It works! See?
      Here's a scalar test value: 3.14159. |}]
