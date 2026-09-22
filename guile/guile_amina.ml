open! Core
open! Amina
open! Amina.Rewrite

(*
  Note: in what follows, we reimplement the Rewrite function defined in
  Amina.Rewrite, but make it a pure function that does not depend on the
  Lwt monad. To do this, we have to drop support for the Include tag.
*)

let rewrite_tag = function
| Expr_tag -> rewrite_expr_tag
| Data_tag -> rewrite_data_tag
| Each_tag -> failwith "Error: \"each\" tags can only open sections."
| Each_expr_tag -> failwith "Error: \"each\" tags can only open sections."
| Eval_tag -> failwith "Error: \"eval\" tags can only open sections."
| Include_tag -> failwith "Error: \"include\" tags are not supported within Guile."

let rec rewrite_section = function
| Expr_tag -> failwith "Error: you have an \"expr\" tag opening a section."
| Data_tag -> failwith "Error: you have a \"data\" tag opening a section."
| Each_tag -> rewrite_each_section
| Each_expr_tag -> rewrite_each_expr_section
| Eval_tag -> rewrite_eval_section
| Include_tag -> failwith "Error: you have an \"include\" tag opening a section."

and rewrite_each_section expr content =
  let rewrite_list xs =
    List.map ~f:(fun next_json_context : string ->
        Stack.push json_context_stack next_json_context;
        let result = rewrite content in
        let _ = Stack.pop_exn json_context_stack in
        result
    ) xs
    |> String.concat
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
  let result_expr = eval_string expr in
  let result = Json.of_scm result_expr in
  free_scm_value result_expr;
  result |> function
  | `List xs ->
    List.map ~f:(fun next_json_context ->
        Stack.push json_context_stack next_json_context;
        let result = rewrite content in
        let _ = Stack.pop_exn json_context_stack in
        result
    ) xs
    |> String.concat
  | x ->
    Stack.push json_context_stack x;
    let result = rewrite content in
    let _ = Stack.pop_exn json_context_stack in
    result

and rewrite_eval_section _expr content =
  rewrite content |> rewrite_string

and rewrite content =
  List.map ~f:(function
    | Text text -> rewrite_text text
    | Tag (tag, expr) -> rewrite_tag tag expr
    | Section (tag, expr, content) -> rewrite_section tag expr content
    ) content
  |> String.concat

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

let _ =
  Scheme.init ();
  Rewrite.init_contexts `Null;
  Callback.register "amina_rewrite_string" rewrite_string