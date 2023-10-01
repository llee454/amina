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
  | _ when Pair.is_cons x -> `List (List.of_raw of_scm x)
  | _ when Bool.is_bool x -> `Bool (Bool.from_raw x)
  | _ when Number.is_integer x -> `Int (Number.int_from_raw x)
  | _ when Number.is_number x -> `Float (Float.of_string (to_string x))
  | _ when Char.is_char x -> `String (Char.from_raw x |> Core.String.of_char)
  | _ when String.is_string x -> `String (String.from_raw x)
  | _ when Symbol.is_symbol x -> `String (to_string x)
  | _ -> `String (to_string x)
