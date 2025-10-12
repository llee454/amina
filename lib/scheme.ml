open! Core
open Aux

include Amina_guile.Make_amina_api (struct
  open Amina_guile

  let parse_path path =
    if is_string path
    then to_string path |> Path.parse_string |> [%sexp_of: Path.path] |> scm_of_sexp
    else
      failwiths ~here:[%here]
        "Error: an error occured while trying to call parse-path. Parse-path only accepts strings that \
         represent JSON path expressions. You did not call parse-path on a string argument."
        () [%sexp_of: unit]

  let get_data_aux path =
    if is_string path
    then (
      let root = Rewrite.get_root_json_context ()
      and local = Rewrite.get_local_json_context () in
      let result = from_string path |> Path.eval_string ~root ~local in
      if !debug_mode
      then
        eprintf
          !"[DEBUG] path=\"%s\"\n\
            [DEBUG] local context=\"%{Yojson.Basic.pretty_to_string}\n\
            [DEBUG] root context=\"%{Yojson.Basic.pretty_to_string}\"\n\
            [DEBUG] result=\"%{Yojson.Basic.pretty_to_string}\"\n"
          (to_string path) local root result;
      (* [%sexp_of: Json.t] result |> scm_of_sexp *)
      Json.to_scm result
    )
    else
      failwiths ~here:[%here]
        "Error: an error occured while trying to evaluate a call to get-data. get-data expects a single \
         string argument that represents a JSON path expression."
        () [%sexp_of: unit]

  (*
    Accepts one argument: path, a string that represents a JSON path expression;
    and an optional argument: json, a JSON object.

    When passed only path, this function reads the JSON value referenced by path
    from either the Root or Local JSON contexts.

    When passed json, this function will read a JSON value from json instead of
    the Local context.
  *)
  let get_data path json =
    if !debug_mode then eprintf !"[DEBUG] get-data json == %{Core.Sexp}\n" (sexp_of_scm json);
    if is_null json
    then get_data_aux path
    else begin
      let _ = Json.of_scm (car json) |> Stack.push Rewrite.json_context_stack in
      let result = get_data_aux path in
      if !warn_mode && is_null result
      then
        eprintf
          !"[WARNING] You referenced a null value using the path \"%{Core.Sexp}\".\n"
          (sexp_of_scm path);
      let _ = Stack.pop Rewrite.json_context_stack in
      result
    end

  (*
    Accepts two arguments: f, a lambda expression; and json, a JSON object; sets
    the local JSON context to equal json and calls f.
  *)
  let call_with_local_context f json =
    let _ = Json.of_scm json |> Stack.push Rewrite.json_context_stack in
    let result = eval f in
    let _ = Stack.pop Rewrite.json_context_stack in
    result

  let num_to_string x args =
    if is_number x
    then (
      let decimals =
        if is_null args
        then None
        else (
          match car args with
          | arg when is_integer arg -> Some (from_integer arg)
          | _ ->
            failwith
              "Error: an error occured while trying to call num->string. Num->string accepts one \
               optional argument that specifies the number of decimal points to display and which must \
               be an integer. You passed a non integer value to num->string."
        )
      in
      to_string x |> Float.of_string |> Float.to_string_hum ~delimiter:',' ?decimals |> string_to_string
    )
    else
      failwiths ~here:[%here]
        "Error: an error occured while trying to call num->string. Num->string can only be called on a \
         number. You did not pass a number to it. Instead, you passed."
        (to_string x) [%sexp_of: string]

  let string_to_num x =
    if is_string x
    then (
      let s =
        from_string x
        |> Core.String.chop_prefix_if_exists ~prefix:"+"
        |> Core.String.substr_replace_all ~pattern:"," ~with_:""
        |> Core.String.substr_replace_all ~pattern:"_" ~with_:""
      in
      Float.of_string_opt s |> function
      | Some value -> to_double value
      | None ->
        failwiths ~here:[%here]
          "Error: an error occured while trying to call string->num. The string that you passed does not \
           represent a number."
          (to_string x) [%sexp_of: string]
    )
    else if is_number x
    then x
    else
      failwiths ~here:[%here]
        "Error: an error occured while trying to call string->num. String->num accepts a string as its \
         only argument. You did not pass a string to it."
        (to_string x) [%sexp_of: string]

  (**
    Accepts one argument: x, a scheme value; and returns a Scheme string
    that represents x in JSON format.
  *)
  let to_json_string x =
    Json.of_scm x |> Json.to_string |> string_to_string
end)
