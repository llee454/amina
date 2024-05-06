open! Core
include Yojson.Safe

let rec sexp_of_t : Yojson.Safe.t -> Sexp.t = function
| `Null -> Sexp.List []
| `Bool b -> Sexp.Atom (if b then "#t" else "#f")
| `Int n -> Sexp.Atom (sprintf "%d" n)
| `Intlit s -> Sexp.Atom s
| `Float x -> Sexp.Atom (sprintf "%f" x)
| `String s -> Sexp.Atom (sprintf "\"%s\"" s)
| `Assoc xs ->
  Sexp.List
    (List.map xs ~f:(fun (key, data) -> Sexp.List [ Sexp.Atom (sprintf "\"%s\"" key); sexp_of_t data ]))
| `List xs -> Sexp.List (List.map xs ~f:sexp_of_t)
| `Tuple xs -> Sexp.List (List.map xs ~f:sexp_of_t)
| `Variant (key, data_opt) ->
  Option.value_map ~default:(Sexp.List []) data_opt ~f:(fun data ->
      Sexp.List [ Sexp.Atom (sprintf "\"%s\"" key); sexp_of_t data ]
  )

(** Accepts a Scheme value and returns an approximate JSON value *)
let rec of_scm x : Yojson.Safe.t =
  let open Guile in
  match () with
  | _ when List.is_null x -> `List []
  | _ when Pair.is_cons x -> (
    try `List (List.of_raw of_scm x) with
    | Failure msg ->
      failwithf
        "Error: an internal error occured while trying to convert a Scheme expression (\"%s\") into a \
         JSON expression. %s"
        (to_string x) msg ()
    | _ ->
      failwithf
        "Error: an internal error occured while trying to convert a Scheme expression (\"%s\") into a \
         JSON expression."
        (to_string x) ()
  )
  | _ when Bool.is_bool x -> `Bool (Bool.from_raw x)
  | _ when Number.is_exact_integer x -> `Int (Number.int_from_raw x)
  | _ when Number.is_number x -> `Float (Number.Float.from_raw x)
  | _ when Char.is_char x -> `String (Char.from_raw x |> Core.String.of_char)
  | _ when String.is_string x -> `String (String.from_raw x)
  | _ when Symbol.is_symbol x -> `String (Symbol.from_raw x)
  | _ ->
    failwithf
      "Error: an internal error occured while trying to convert a Scheme expression (\"%s\") into a JSON \
       expression. We couldn't recognize the type Scheme expression's type. It wasn't a string, integer, \
       etc."
      (to_string x) ()
