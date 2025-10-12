open! Core

type scm

(**
  Initialize Guile so that all code executed within the current thread
  can access the Guile environment.
*)
external init_guile : unit -> unit = "scm_init_guile"

(**
  Accepts an OCaml Scheme value and returns a string that represents it.

  Note: if the value represents a string, this function unescapes the
  quotation marks.
*)
external to_string_pretty : scm -> string = "amina_to_string_pretty"

(**
  Accepts an OCaml Scheme value and returns a string that represents it.
*)
external to_string : scm -> string = "amina_to_string"

let amina_to_string = to_string

(**
  Accepts an OCaml Scheme expression, evaluates it, and returns the
  result as an OCaml Scheme expression.
*)
external eval : scm -> scm = "amina_eval"

(**
  Accepts one argument: [expr], a string that represents a Scheme
  expression; evaluates [expr]; and returns the result as a string
  value.

  WARNING: you must initialize the Guile environment before you call
  this function.
*)
external eval_string : string -> scm = "amina_eval_string"

(**
  Accepts an OCaml string that represents a Scheme file name; loads
  the referenced file; and returns the result as an OCaml Scheme
  value.
*)
external load : string -> scm = "amina_load"

(**
  Returns Scheme's END OF LIST value. Note: this value is often called
  Nil and represented using '().
*)
external eol : unit -> scm = "amina_eol"

external is_string : scm -> bool = "amina_is_string"
external is_symbol : scm -> bool = "amina_is_symbol"
external is_number : scm -> bool = "amina_is_number"
external is_integer : scm -> bool = "amina_is_integer"
external is_exact_integer : scm -> bool = "amina_is_exact_integer"
external is_bool : scm -> bool = "amina_is_bool"
external is_char : scm -> bool = "amina_is_char"
external is_null : scm -> bool = "amina_is_null"
external is_pair : scm -> bool = "amina_is_pair"
external is_list : scm -> bool = "amina_is_list"
external is_vector : scm -> bool = "amina_is_vector"
external cons : scm -> scm -> scm = "amina_cons"
external car : scm -> scm = "amina_car"
external cdr : scm -> scm = "amina_cdr"
external vector_to_list : scm -> scm = "amina_vector_to_list"
external length : scm -> int = "amina_length"
external from_integer : scm -> int = "amina_from_integer"
external from_double : scm -> float = "amina_from_double"
external from_bool : scm -> bool = "amina_from_bool"
external from_char : scm -> int = "amina_from_char"
external from_string : scm -> string = "amina_from_string"

let amina_from_string = from_string

external from_symbol : scm -> string = "amina_from_symbol"
external to_integer : int -> scm = "amina_to_integer"
external to_double : float -> scm = "amina_to_double"
external to_bool : bool -> scm = "amina_to_bool"
external string_to_string : string -> scm = "amina_string_to_string"

(** Accepts a list of Scheme values and returns a them in a Scheme list. *)
let to_list (xs : scm list) : scm = List.fold_right xs ~init:(eol ()) ~f:cons

(**
  Accepts two arguments: [f], a function that accepts a Scheme value
  and returns some value; and [x], a scheme list; and returns a
  list of [f x0, f x1, ...].
*)
let rec from_list ~(f : scm -> 'a) (x : scm) : 'a List.t =
  if is_pair x then f (car x) :: from_list ~f (cdr x) else if is_null x then [] else [ f x ]

(**
  Accepts two arguments: [f], a function that accepts a Scheme value
  and returns some value; and [x], a scheme vector; and returns a
  list of [f x0, f x1, ...].
*)
let from_vector ~(f : scm -> 'a) (x : scm) : 'a List.t =
  if is_vector x then from_list ~f (vector_to_list x) else if is_null x then [] else [ f x ]

(**
  Accepts two arguments: [f], a function that accepts a Scheme value
  and returns some value; and [x], a Scheme associative array; and
  returns the associative array [(key0, f x0), (key1, f x1), ...].
*)
let rec from_alist ~f:(f : scm -> 'a) (x : scm) : (string * 'a) List.t =
  let emsg_prefix = "Error: an internal error occured while trying to convert an associative array (alist) into an OCaml value. "
  in match () with
  | () when is_null x -> []
  | () when is_pair x ->
      if is_pair (car x)
      then
        let key = match () with
          | () when is_string (car (car x)) -> amina_from_string (car (car x))
          | () when is_symbol (car (car x)) -> from_symbol (car (car x))
          | _ -> failwiths ~here:[%here] (emsg_prefix ^ "One or more entries in the list is missing a key value.") (amina_to_string x) [%sexp_of: string]
        in
        (key, f (cdr (car x))) :: from_alist ~f (cdr x)
      else failwiths ~here:[%here] (emsg_prefix ^ "One or more entries is not in (key . value) format. Instead a scalar value was found.") (amina_to_string x)[%sexp_of: string] 
  | _ -> failwiths ~here:[%here] (emsg_prefix ^ "The given value is not even a list") (amina_to_string x) [%sexp_of: string]

let rec scm_of_sexp : Sexplib.Sexp.t -> scm = function
| Atom s -> (
  match Int.of_string_opt s with
  | Some x -> to_integer x
  | None -> (
    (match Float.of_string_opt s with Some x -> to_double x | None -> string_to_string s)
  )
)
| List xs -> List.map xs ~f:scm_of_sexp |> to_list

let rec sexp_of_scm (x : scm) : Sexplib.Sexp.t =
  if is_pair x
  then List (from_list ~f:sexp_of_scm x)
  else if is_vector x
    then List (from_vector ~f:sexp_of_scm x)
  else
    Atom (to_string x)

module Json = struct
  include Yojson.Basic

  let rec to_scm : Yojson.Basic.t -> scm = function
  | `Null -> eol ()
  | `Bool b -> to_bool b
  | `Int n -> to_integer n
  | `Float x -> to_double x
  | `String s -> string_to_string s
  | `Assoc xs ->
    List.map xs ~f:(fun (key, data) -> to_list [ string_to_string key; to_scm data ]) |> to_list
  | `List xs -> to_list (List.map xs ~f:to_scm)

  (**
    Accepts a Scheme value and returns true iff the value represents an
    associative list.

    For a Scheme list to be treated like an associative list, it must have
    the format

      '((key0 . value0) (key1 . value1) ...)

    where none of the values can be null (the empty list).
  *)
  let rec is_alist (x : scm) : bool =
    let key x = car (car x)
    in
    is_null x ||
    (is_pair x && is_pair (car x)
      && not (is_list (car x))
      && (is_string (key x) || is_symbol (key x))
      && is_alist (cdr x))
  
  let rec to_json ?(return_assoc = false) (x : scm) : Yojson.Basic.t =
    match () with
    | () when is_null x -> `List []
    | () when return_assoc && is_alist x -> `Assoc (from_alist ~f:(to_json ~return_assoc) x)
    | () when is_pair x -> `List (from_list ~f:(to_json ~return_assoc) x)
    | () when is_vector x -> `List (from_vector ~f:(to_json ~return_assoc) x)
    | () when is_bool x -> `Bool (from_bool x)
    | () when is_exact_integer x -> `Int (from_integer x)
    | () when is_number x -> `Float (from_double x)
    | () when is_char x -> `String (from_char x |> Char.of_int_exn |> String.of_char)
    | () when is_string x -> `String (amina_from_string x)
    | () when is_symbol x -> `String (from_symbol x)
    | () ->
      failwithf
        "Error: an internal error occured while trying to convert a Scheme expression (%s) into a JSON \
         expression. We couldn't recognize the type Scheme expression's type. It wasn't a string, \
         integer, etc."
        (amina_to_string x) ()

  let of_scm (x : scm) : Yojson.Basic.t = to_json ~return_assoc:false x
end

module type Amina_api = sig
  val parse_path : scm -> scm
  val get_data_aux : scm -> scm
  val get_data : scm -> scm -> scm
  val call_with_local_context : scm -> scm -> scm
  val num_to_string : scm -> scm -> scm
  val string_to_num : scm -> scm
  val to_json_string : scm -> scm
end

module Make_amina_api (M : Amina_api) = struct
  external register_parse_path : unit -> unit = "amina_register_parse_path"
  external register_get_data_aux : unit -> unit = "amina_register_get_data_aux"
  external register_get_data : unit -> unit = "amina_register_get_data"
  external register_call_with_local_context : unit -> unit = "amina_register_call_with_local_context"
  external register_num_to_string : unit -> unit = "amina_register_num_to_string"
  external register_string_to_num : unit -> unit = "amina_register_string_to_num"
  external register_to_json : unit -> unit = "amina_register_to_json"

  let init () =
    Callback.register "parse-path" M.parse_path;
    Callback.register "get-data-aux" M.get_data_aux;
    Callback.register "get-data" M.get_data;
    Callback.register "call-with-local-context" M.call_with_local_context;
    Callback.register "num->string" M.num_to_string;
    Callback.register "string->num" M.string_to_num;
    Callback.register "to-json" M.to_json_string;
    register_parse_path ();
    register_get_data_aux ();
    register_get_data ();
    register_call_with_local_context ();
    register_num_to_string ();
    register_string_to_num ();
    register_to_json ();
end
