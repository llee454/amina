open! Core
open! Guile

let null_scm = List.to_raw Fn.id []

let define_parse_path () =
  Functions.register_fun1 "parse-path" (fun (path : scm) ->
      if String.is_string path
      then String.from_raw path |> Path.parse_string |> [%sexp_of: Path.path] |> Guile.Sexp.to_raw
      else
        Error.error ~fn_name:"parse-path"
          "Error: an error occured while trying to call parse-path. Parse-path only accepts strings that \
           represent JSON path expressions. You did not call parse-path on a string argument."
  )

let define_get_data () =
  Functions.register_fun1 "get-data" (fun (path : scm) ->
      if String.is_string path
      then
        String.from_raw path
        |> Path.eval_string ~root:(Rewrite.get_root_json_context ())
             ~local:(Rewrite.get_local_json_context ())
        |> [%sexp_of: Json.t]
        |> Guile.Sexp.to_raw
      else
        Error.error ~fn_name:"get-data"
          "Error: an error occured while trying to evaluate a call to get-data. get-data expects a \
           single string argument that represents a JSON path expression."
  )

let define_get_scheme_data () =
  Functions.register_fun2 "get-scheme-data" (fun (path_scm : scm) (data : scm) : scm ->
      let open Path in
      if String.is_string path_scm
      then (
        let ({ base; refs } as path) = String.from_raw path_scm |> parse_string in
        match base with
        | Root ->
          eval_with (Rewrite.get_root_json_context ()) path |> [%sexp_of: Json.t] |> Guile.Sexp.to_raw
        | Local ->
          Core.List.fold refs ~init:data ~f:(fun acc -> function
            | Field field_name ->
              if Pair.is_cons acc
              then
                List.of_raw Fn.id acc
                |> Core.List.find_map ~f:(fun x ->
                       if Pair.is_cons x
                          && (not (List.is_null x))
                          && String.is_string (Pair.car x)
                          && not (List.is_null (Pair.cdr x))
                       then (
                         let curr_field_name = String.from_raw (Pair.car x) in
                         Option.some_if ([%equal: string] field_name curr_field_name) (Pair.cadr x)
                       )
                       else None
                   )
                |> Option.value ~default:null_scm
              else null_scm
            | Index index ->
              if Pair.is_cons acc
              then
                List.of_raw Fn.id acc
                |> (fun xs -> Core.List.nth xs index)
                |> Option.value ~default:null_scm
              else null_scm
          )
      )
      else
        Error.error ~fn_name:"get-scheme-data"
          "Error: an error occured while trying to call get-scheme-data. Get-scheme-data accepts two \
           arguments: path and data. Path must be a string that represents a JSON path expression. Data \
           is a Scheme datastructure that should be a translated JSON value. You called get-scheme-data \
           without passing a string argument."
  )

let define_float_to_string () =
  Functions.register_fun2 "float-to-string" ~no_opt:1 ~rst:true (fun (x : scm) (args : scm) ->
      if Number.is_number x
      then (
        let decimals =
          if Pair.is_cons args
          then
            if List.is_null args
            then None
            else (
              match Pair.car args with
              | arg when Number.is_integer arg -> Some (Number.int_from_raw arg)
              | _ ->
                failwith
                  "Error: an error occured while trying to call float_to_string. Float_to_string accepts \
                   one optional argument that specifies the number of decimal points to display and \
                   which must be an integer. You passed a non integer value to float-to-string."
            )
          else
            failwiths ~here:[%here]
              "Error: an internal error occured while trying to call float_to_string. You called the \
               function with optional arguments and Scheme did not return the optional arguments in a \
               list."
              () [%sexp_of: unit]
        in
        to_string x |> Float.of_string |> Float.to_string_hum ~delimiter:',' ?decimals |> String.to_raw
      )
      else
        Error.error ~fn_name:"float_to_string"
          "Error: an error occured while trying to call float_to_string. float_to_string can only be \
           called on a floating point number. You did not pass a floating point number to it."
  )

let init () =
  Guile.init ();
  let _ = define_parse_path ()
  and _ = define_get_data ()
  and _ = define_get_scheme_data ()
  and _ = define_float_to_string () in
  Gc.full_major ();
  ()
