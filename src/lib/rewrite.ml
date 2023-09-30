(*
  TODO:
  - [ ] allow white space in expressions
  - [ ] allow escaping braces
*)

open! Core
open! Aux
open! Angstrom

(**
  Accepts two parsers p and q that return strings and returns a new
  parser that matches both p and q consecutively and concatenates their
  outcome.
*)
let ( <^> ) p q = ( ^ ) <$> p <*> q

(**
  Accepts two parsers p and q and returns a new parser that matches
  both p and q consecutively and returns their results in a pair.
*)
let ( <&> ) p q = (fun s r -> s, r) <$> p <*> q

type tag_type =
  | Expr_tag
  | Data_tag
  | Each_tag
[@@deriving equal, sexp]

let tag_type_of_string = function
| "expr" -> Expr_tag
| "data" -> Data_tag
| "each" -> Each_tag
| s -> failwithf "Error: \"%s\" is an invalid tag name." s ()

let tag_type_to_string = function Expr_tag -> "expr" | Data_tag -> "data" | Each_tag -> "each"
let json_context_stack = Stack.create ()
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
let is_colon = Char.equal ':'
let lex_open_brace = string "{"
let lex_close_brace = string "}"
let lex_colon = string ":"
let lex_pound = string "#"
let lex_slash = string "/"

(* TODO: add escaping *)
let parse_text = take_while1 (Fn.compose not is_open_brace) >>| fun s -> Text s

let%expect_test "parse_text" =
  "This is a test. {expr: 55}"
  |> Angstrom.parse_string ~consume:Prefix parse_text
  |> Result.ok_or_failwith
  |> printf !"%{sexp: grammar}";
  [%expect {| (Text "This is a test. ") |}]

let parse_tag_name =
  take_while1 (fun c ->
      (not (is_colon c)) && (not (is_pound c)) && (not (is_slash c)) && not (is_close_brace c)
  )
  >>| tag_type_of_string

(* TODO: add escaping *)
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
            >>| fun ((tag, expr), content) -> Section (tag, expr, content)
            )
        )
  )

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
  let json_context = Stack.top_exn json_context_stack in
  match parse_string ~consume:All Path.parse_path expr with
  | Error msg -> failwithf "Error: an error occured while trying to handle a JSON path. %s" msg ()
  | Ok parser -> parser json_context |> Yojson.Safe.pretty_to_string

let rewrite_tag = function
| Expr_tag -> rewrite_expr_tag
| Data_tag -> rewrite_data_tag
| Each_tag -> failwith "Error: \"each\" tags can only open sections."

let rec rewrite_section = function
| Expr_tag -> failwith "Error: you have an \"expr\" tag opening a section."
| Data_tag -> failwith "Error: you have a \"data\" tag opening a section."
| Each_tag -> rewrite_each_section

and rewrite_each_section expr content =
  let json_context = Stack.top_exn json_context_stack in
  match parse_string ~consume:All Path.parse_path expr with
  | Error msg -> failwithf "Error: an error occured while trying to handle a JSON path. %s" msg ()
  | Ok parser -> begin
    match parser json_context with
    | `List xs | `Tuple xs ->
      List.map xs ~f:(fun next_json_context ->
          Stack.push json_context_stack next_json_context;
          let result = rewrite content in
          let _ = Stack.pop_exn json_context_stack in
          result
      )
      |> String.concat
    | _ ->
      failwithf
        "Error: tried to open an \"each\" section on a JSON value that was not an array or tuple. You \
         can only open \"each\" sections on JSON arrays and tuples. The expression was \"%s\"."
        expr ()
  end

and rewrite content =
  List.map content ~f:(function
    | Text text -> rewrite_text text
    | Tag (tag, expr) -> rewrite_tag tag expr
    | Section (tag, expr, content) -> rewrite_section tag expr content
    )
  |> String.concat

let%expect_test "rewrite" =
  Guile.init ();
  {json|
     {
       "example_array": [1, 2, 3]
     }
   |json}
  |> Yojson.Safe.from_string
  |> Stack.push json_context_stack;
  "This is a test expression {expr: (* 3 7)}. Here's a data {data:.example_array[1]}. Here's a section \
   {#each:.example_array}Item:{data:.} {/each}. It works! See?"
  |> Angstrom.parse_string ~consume:Prefix parse
  |> Result.ok_or_failwith
  |> rewrite
  |> printf "%s";
  (* |> printf !"%{sexp: grammar list}"; *)
  [%expect {| This is a test expression 21. Here's a data 2. Here's a section Item:1 Item:2 Item:3 . It works! See? |}]
