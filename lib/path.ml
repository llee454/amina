open! Core
open! Angstrom
open! Aux

type reference =
  | Field of string
  | Index of int
[@@deriving sexp]

type base_ref =
  | Root
  | Local
[@@deriving sexp, equal]

let base_ref_of_string = function
| "root" -> Root
| "local" -> Local
| s ->
  failwithf
    "Error: an error occured while trying to parse a JSON path. Your path contained an invalid base \
     reference (\"%s\"). Paths must start with either \"root\" or \"local\"."
    s ()

type path = {
  base: base_ref;
  refs: reference list;
}
[@@deriving sexp]

let is_dot = Char.equal '.'
let is_left_bracket = Char.equal '['
let is_special c = is_dot c || is_left_bracket c
let lex_dot = string "."
let lex_open_bracket = string "["
let lex_close_bracket = string "]"
let lex_int = take_while1 (function '0' .. '9' -> true | _ -> false) >>| int_of_string
let lex_text = take_while (not <| is_special)
let lex_text1 = take_while1 (not <| is_special)
let parse_base_ref = lex_text1 >>| base_ref_of_string
let parse_field = lex_dot *> lex_text1 >>| fun x -> Field x
let parse_index = lex_open_bracket *> lex_int <* lex_close_bracket >>| fun n -> Index n
let parse = parse_base_ref <&> many (parse_field <|> parse_index) >>| fun (base, refs) -> { base; refs }

let parse_string path =
  match parse_string ~consume:All parse path with
  | Error msg -> failwithf "Error: an error occured while trying to parse a JSON path. %s" msg ()
  | Ok parsing -> parsing

let%expect_test "parse0" =
  parse_string "root" |> printf !"%{sexp: path}";
  [%expect {| ((base Root) (refs ())) |}]

let%expect_test "parse1" =
  parse_string "root.example[0]" |> printf !"%{sexp: path}";
  [%expect {| ((base Root) (refs ((Field example) (Index 0)))) |}]

let eval_field field : Yojson.Safe.t -> Yojson.Safe.t = function
| `Null -> `Null
| `Assoc xs -> begin
  (match List.Assoc.find ~equal:String.equal xs field with Some json -> json | None -> `Null)
end
(* When JSON objects are mapped to Scheme values and back again to JSON they are transformed into lists. *)
| `List xs ->
  List.find_map xs ~f:(function
    | `List [ `String key; value ] when String.equal field key -> Some value
    | _ -> None
    )
  |> Option.value_map ~default:`Null ~f:(fun json -> json)
| _ ->
  failwithf
    "Error: an error occured while trying to evaluate a JSON path. You applied a field reference \
     (\"%s\") to a JSON value that is not an object."
    field ()

let eval_index index = function
| `Null -> `Null
| `List xs | `Tuple xs -> begin (match List.nth xs index with Some json -> json | None -> `Null) end
| _ ->
  failwithf
    "Error: an error occured while trying to evaluate a JSON path. You applied an array reference to a \
     JSON value that is not an array."
    ()

let eval_with (context : Yojson.Safe.t) path =
  List.fold path.refs ~init:context ~f:(fun acc -> function
    | Field field -> eval_field field acc | Index index -> eval_index index acc
  )

let eval ~(root : Yojson.Safe.t) ~(local : Yojson.Safe.t) (path : path) =
  let init = (match path.base with Root -> root | Local -> local) in
  eval_with init path

let eval_string ~root ~local path =
  try parse_string path |> eval ~root ~local with
  | Failure msg ->
    failwithf "Error: an error occured while trying to parse a JSON path (\"%s\"). %s" path msg ()
  | _ ->
    failwithf
      "Error: an error occured while trying to parse a JSON path (\"%s\"). We were unable to parse the \
       entire path expression as it contains one or more syntax errors."
      path ()

let%expect_test "eval_string" =
  let root = {json|
    {
      "example": [1, 2, 3]
    }
  |json} |> Yojson.Safe.from_string in
  let local = root in
  eval_string ~root ~local "root.example[0]" |> printf !"%{Yojson.Safe.pretty_to_string}";
  [%expect {| 1 |}]
