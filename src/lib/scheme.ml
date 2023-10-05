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

let define_get_data_aux () =
  Functions.register_fun1 "get-data-aux" (fun (path : scm) ->
      if String.is_string path
      then
        String.from_raw path
        |> Path.eval_string ~root:(Rewrite.get_root_json_context ())
             ~local:(Rewrite.get_local_json_context ())
        |> [%sexp_of: Json.t]
        |> Guile.Sexp.to_raw
      else
        Error.error ~fn_name:"get-data-aux"
          "Error: an error occured while trying to evaluate a call to get-data-aux. get-data-aux expects \
           a single string argument that represents a JSON path expression."
  )

let define_push_local_context () =
  Functions.register_fun1 "push-local-context!" (fun (json : scm) ->
      Json.of_scm json |> Stack.push Rewrite.json_context_stack;
      eol
  )

let define_pop_local_context () =
  Functions.register_fun1 "pop-local-context!" ~no_opt:1 ~rst:true (fun args ->
      if List.is_null args
      then (
        let _ = Stack.pop Rewrite.json_context_stack in
        eol
      )
      else
        Error.error ~fn_name:"pop-local-context"
          "Error: an error occured while trying to call pop-local-context. This function doesn't take \
           any arguments yet you passed it one."
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
  and _ = define_get_data_aux ()
  and _ = define_push_local_context ()
  and _ = define_pop_local_context ()
  and _ = define_float_to_string () in
  let _ = eval_string [%blob "init.scm"] in
  Gc.full_major ();
  ()
