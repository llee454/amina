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
  Sexp.List (List.map xs ~f:(fun (key, data) ->
    Sexp.List [
      Sexp.Atom (sprintf "\"%s\"" key);
      sexp_of_t data
    ]
  ))
| `List xs -> Sexp.List (List.map xs ~f:sexp_of_t)
| `Tuple xs -> Sexp.List (List.map xs ~f:sexp_of_t)
| `Variant (key, data_opt) ->
  Option.value_map ~default:(Sexp.List[]) data_opt ~f:(fun data ->
    Sexp.List [
      Sexp.Atom (sprintf "\"%s\"" key);
      sexp_of_t data
    ]
  )