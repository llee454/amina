open! Core
open! Angstrom
open! Aux

type tag_type =
  | Expr_tag
  | Data_tag
  | Each_tag
  | Each_expr_tag
  | Eval_tag
  | Include_tag
[@@deriving equal, sexp]

let tag_type_of_string = function
| "expr" -> Expr_tag
| "data" -> Data_tag
| "each" -> Each_tag
| "each-expr" -> Each_expr_tag
| "eval" -> Eval_tag
| "include" -> Include_tag
| s -> failwithf "Error: \"%s\" is an invalid tag name." s ()

let tag_type_to_string = function
| Expr_tag -> "expr"
| Data_tag -> "data"
| Each_tag -> "each"
| Each_expr_tag -> "each-expr"
| Eval_tag -> "eval"
| Include_tag -> "include"

let root_json_context = ref None

let get_root_json_context () : Yojson.Basic.t =
  match !root_json_context with
  | None ->
    failwith
      "Error: an internal error occured. You probabily tried to evaluate a JSON path without first \
       setting the root JSON context."
  | Some json -> json

let json_context_stack = Stack.create ()

let get_local_json_context () : Yojson.Basic.t =
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

let parse_text_token =
  let* n = available in
  if n < 2 then any_char
  else 
    let* s = Angstrom.peek_string 2 in
    match String.to_list s with
    | ['\\'; '{'] -> advance 2 *> return '{'
    | ['\\'; '\\'] -> advance 2 *> return '\\'
    | ['{'; '{'] -> fail "Encountered the start of an Amina open tag while looking for a text token."
    | _ -> any_char

let parse_text =
  let+ cs = many1 (parse_text_token) in
  Text (String.of_char_list cs)

let%expect_test "parse_text" =
  {|This is a test. \{not a tag\\} {{expr: 55}}|}
  |> Angstrom.parse_string ~consume:Prefix parse_text
  |> Result.ok_or_failwith
  |> printf !"%{sexp: grammar}";
  [%expect {| (Text "This is a test. {not a tag\\\\} ") |}]

let parse_tag_name =
  take_while1 (fun c ->
      (not (is_colon c)) && (not (is_pound c)) && (not (is_slash c)) && not (is_close_brace c)
  )
  >>| tag_type_of_string

let parse_tag_content = take_till is_close_brace

let parse_tag =
  lex_open_brace *> lex_open_brace *> parse_tag_name <&> lex_colon *> parse_tag_content <* lex_close_brace <* lex_close_brace >>| fun (t, s) ->
  Tag (t, s)

let%expect_test "parse_tag" =
  "{{expr: 55}}"
  |> Angstrom.parse_string ~consume:All parse_tag
  |> Result.ok_or_failwith
  |> printf !"%{sexp: grammar}";
  [%expect {| (Tag Expr_tag " 55") |}]

let parse_open_section_tag =
  lex_open_brace *> lex_open_brace *> lex_pound *> parse_tag_name <&> option "" (lex_colon *> parse_tag_content) <* lex_close_brace <* lex_close_brace
  >>| fun (tag, s) ->
  Stack.push tag_stack tag;
  tag, s

let parse_close_section_tag =
  lex_open_brace *> lex_open_brace *> lex_slash *> parse_tag_name <* lex_close_brace <* lex_close_brace >>| fun tag ->
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
  |> Yojson.Basic.from_string
  |> Stack.push json_context_stack;
  "This is an expression {{expr: (* 3 7)}} and this is a section {{#each: .example_array}}That has a nested \
   tag: {{data: .}}{{/each}}"
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
let rewrite_expr_tag expr = Amina_guile.(eval_string expr |> to_string_pretty)

let rewrite_data_tag expr =
  Path.eval_string ~root:(get_root_json_context ()) ~local:(get_local_json_context ()) expr |> function
  | `Null -> ""
  | `String string -> string
  | json -> Yojson.Basic.pretty_to_string json

let rewrite_include_tag expr =
  read_file ~filename:expr

let rewrite_tag = function
| Expr_tag -> Fn.compose Lwt.return rewrite_expr_tag
| Data_tag -> Fn.compose Lwt.return rewrite_data_tag
| Each_tag -> failwith "Error: \"each\" tags can only open sections."
| Each_expr_tag -> failwith "Error: \"each\" tags can only open sections."
| Eval_tag -> failwith "Error: \"eval\" tags can only open sections."
| Include_tag -> rewrite_include_tag

let rec rewrite_section = function
| Expr_tag -> failwith "Error: you have an \"expr\" tag opening a section."
| Data_tag -> failwith "Error: you have a \"data\" tag opening a section."
| Each_tag -> rewrite_each_section
| Each_expr_tag -> rewrite_each_expr_section
| Eval_tag -> rewrite_eval_section
| Include_tag -> failwith "Error: you have an \"include\" tag opening a section."

and rewrite_each_section expr content =
  let open Lwt.Syntax in
  let open Lwt.Infix in
  let rewrite_list xs =
    Lwt_list.map_p (fun next_json_context : string Lwt.t ->
        Stack.push json_context_stack next_json_context;
        let+ result = rewrite content in
        let _ = Stack.pop_exn json_context_stack in
        result
    ) xs
    >|= String.concat
  in
  match Path.eval_string ~root:(get_root_json_context ()) ~local:(get_local_json_context ()) expr with
  | `List xs -> rewrite_list xs
  | `Assoc xs -> List.map xs ~f:(fun (key, x) -> `List [ `String key; x ]) |> rewrite_list
  | x ->
    Stack.push json_context_stack x;
    let result = rewrite content in
    let _ = Stack.pop_exn json_context_stack in
    result

and rewrite_each_expr_section expr content =
  let open Amina_guile in
  let open Lwt.Infix in
  eval_string expr |> Json.of_scm |> function
  | `List xs ->
    Lwt_list.map_p (fun next_json_context ->
        Stack.push json_context_stack next_json_context;
        let result = rewrite content in
        let _ = Stack.pop_exn json_context_stack in
        result
    ) xs
    >|= String.concat
  | x ->
    Stack.push json_context_stack x;
    let result = rewrite content in
    let _ = Stack.pop_exn json_context_stack in
    result

and rewrite_eval_section _expr content =
  Lwt.Infix.((rewrite content) >>= (rewrite_string))

and rewrite content =
  let open Lwt.Infix in
  Lwt_list.map_p (function
    | Text text -> Lwt.return @@ rewrite_text text
    | Tag (tag, expr) -> rewrite_tag tag expr
    | Section (tag, expr, content) -> rewrite_section tag expr content
    ) content
  >|= String.concat

(** Accepts a template string and expands the tags contained within it. *)
and rewrite_string template =
  try rewrite (parse_string template) with
  | Failure msg ->
    failwithf !"Error: an error occured while trying to parse and/or rewrite a template. %s" msg ()
  | e ->
    failwithf
      !"Error: an error occured while trying to parse and/or rewrite a template. Perhaps you have an \
        unclosed section tag. The last opened section tag was (\"%{sexp: tag_type option}\"). The \
        exception was: \"%{Exn.to_string}\"."
      (Stack.top tag_stack) e ()
