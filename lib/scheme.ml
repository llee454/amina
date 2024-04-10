open! Core
open! Guile
open Aux

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

let get_data_aux path =
  if String.is_string path
  then (
    let root = Rewrite.get_root_json_context ()
    and local = Rewrite.get_local_json_context () in
    let result = String.from_raw path |> Path.eval_string ~root ~local in
    if !debug_mode
    then
      eprintf
        !"[DEBUG] path=\"%s\"\n\
          [DEBUG] local context=\"%{Yojson.Safe.pretty_to_string}\n\
          [DEBUG] root context=\"%{Yojson.Safe.pretty_to_string}\"\n\
          [DEBUG] result=\"%{Yojson.Safe.pretty_to_string}\"\n"
        (Guile.to_string path) local root result;
    [%sexp_of: Json.t] result |> Guile.Sexp.to_raw
  )
  else
    Error.error ~fn_name:"get-data"
      "Error: an error occured while trying to evaluate a call to get-data. get-data expects a single \
       string argument that represents a JSON path expression."

let define_get_data () =
  (*
    Accepts one argument: path, a string that represents a JSON path expression;
    and an optional argument: json, a JSON object.

    When passed only path, this function reads the JSON value referenced by path
    from either the Root or Local JSON contexts.

    When passed json, this function will read a JSON value from json instead of
    the Local context.
  *)
  Functions.register_fun2 "get-data" ~no_opt:1 ~rst:true (fun path json ->
      if List.is_null json
      then get_data_aux path
      else begin
        let _ = Json.of_scm json |> Stack.push Rewrite.json_context_stack in
        let result = get_data_aux path in
        let _ = Stack.pop Rewrite.json_context_stack in
        result
      end
  )

let define_call_with_local_context () =
  (*
    Accepts two arguments: f, a lambda expression; and json, a JSON object; sets
    the local JSON context to equal json and calls f.
  *)
  Functions.register_fun2 "call-with-local-context" (fun f json ->
      let _ = Json.of_scm json |> Stack.push Rewrite.json_context_stack in
      let result = Guile.eval f in
      let _ = Stack.pop Rewrite.json_context_stack in
      result
  )

let define_num_to_string () =
  Functions.register_fun2 "num->string" ~no_opt:1 ~rst:true (fun (x : scm) (args : scm) ->
      if Number.is_number x
      then (
        let decimals =
          if List.is_null args
          then None
          else (
            match Pair.car args with
            | arg when Number.is_integer arg -> Some (Number.int_from_raw arg)
            | _ ->
              failwith
                "Error: an error occured while trying to call num->string. Num->string accepts one \
                 optional argument that specifies the number of decimal points to display and which must \
                 be an integer. You passed a non integer value to num->string."
          )
        in
        to_string x |> Float.of_string |> Float.to_string_hum ~delimiter:',' ?decimals |> String.to_raw
      )
      else
        Error.error ~fn_name:"num->string"
          (sprintf
             "Error: an error occured while trying to call num->string. Num->string can only be called \
              on a number. You did not pass a number to it. Instead, you passed \"%s\"."
             (Guile.to_string x)
          )
  )

let define_string_to_num () =
  Functions.register_fun1 "string->num" (fun (x : scm) ->
      if String.is_string x
      then (
        let s =
          String.from_raw x
          |> Core.String.chop_prefix_if_exists ~prefix:"+"
          |> Core.String.substr_replace_all ~pattern:"," ~with_:""
          |> Core.String.substr_replace_all ~pattern:"_" ~with_:""
        in
        Float.of_string_opt s |> function
        | Some value -> Number.Float.to_raw value
        | None ->
          Error.error ~fn_name:"string->num"
            (sprintf
               "Error: an error occured while trying to call string->num. The string that you passed \
                \"%s\" does not represent a number."
               s
            )
      )
      else
        Error.error ~fn_name:"string->num"
          (sprintf
             "Error: an error occured while trying to call string->num. String->num accepts a string as \
              its only argument. You did not pass a string to it. Instead, you passed \"%s\"."
             (Guile.to_string x)
          )
  )

let init () =
  Guile.init ();
  let _ = define_parse_path ()
  and _ = define_get_data ()
  and _ = define_call_with_local_context ()
  and _ = define_num_to_string ()
  and _ = define_string_to_num () in
  let _ = eval_string [%blob "init.scm"] in
  Gc.full_major ();
  ()
