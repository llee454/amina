#include <stdlib.h>
#include <string.h>
#include <libguile.h>

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/callback.h>

/**
  Accepts an OCaml Scheme object and returns the associated Guile
  Scheme object.
*/
#define amina_from_ocaml(x) *((SCM*) Data_abstract_val (x))

/**
  Accepts a pointer to a Guile scheme object and returns an OCaml
  reference to that object.

  WARNING: you MUST call `scm_gc_protect_object` on the Guile Scheme
  object before passing it to OCaml. See `amina_free_scm_value`.
*/
CAMLprim value amina_to_ocaml (SCM x) {
  CAMLparam0 ();
  CAMLlocal1 (res);
  scm_gc_protect_object (x);
  res = caml_alloc (1, Abstract_tag);
  *((SCM*) Data_abstract_val (res)) = x;
  CAMLreturn (res);
}

/**
  Accepts an OCaml Scheme value and tells the Scheme garbage collector that
  it can delete the value.

  Note: All values given to OCaml by `amina_to_ocaml` must be freed using
  this function in your OCaml code to avoid memory leaks - resources never
  being deleted when no longer needed.
*/
CAMLprim void amina_free_scm_value (value x) {
  CAMLparam1 (x);
  scm_gc_unprotect_object (amina_from_ocaml (x));
  CAMLreturn0;
}

/**
  Accepts an OCaml Scheme value and returns a string that represents it.

  Note: if the value represents a string, this function unescapes the
  quotation marks.
*/
CAMLprim value amina_to_string_pretty (value x) {
  CAMLparam1 (x);
  CAMLlocal1 (res);
  SCM scm_value_ref = amina_from_ocaml (x);
  char* s = scm_to_locale_string (
    scm_is_string (scm_value_ref) ? scm_value_ref :
    scm_object_to_string (scm_value_ref, SCM_UNDEFINED)
  );
  res = caml_copy_string (s);
  free (s);
  CAMLreturn (res);
}

/**
  Accepts an OCaml Scheme value and returns a string that represents it.
*/
CAMLprim value amina_to_string (value x) {
  CAMLparam1 (x);
  CAMLlocal1 (res);
  SCM scm_value_ref = amina_from_ocaml (x);
  char* s = scm_to_locale_string (scm_object_to_string (scm_value_ref, SCM_UNDEFINED));
  res = caml_copy_string (s);
  free (s);
  CAMLreturn (res);
}

/**
  Accepts an OCaml Scheme expression, evaluates it, and returns the
  result as an OCaml Scheme expression.

  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_eval (value expr) {
  CAMLparam1 (expr);
  CAMLreturn (amina_to_ocaml (scm_eval (amina_from_ocaml (expr), SCM_UNDEFINED)));
}

/**
  Accepts an OCaml string that represents a Scheme expression,
  evaluates the expression, and returns the result as a string.

  WARNING: you must initialize the Guile environment before calling
  this function.

  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_eval_string (value expr) {
  CAMLparam1 (expr);
  CAMLreturn (amina_to_ocaml (scm_c_eval_string (String_val (expr))));
 }

/**
  Accepts an OCaml string that represents a Scheme file name; loads
  the referenced file; and returns the result as an OCaml Scheme
  value.
  
  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_load (value filename) {
  CAMLparam1 (filename);
  CAMLreturn (amina_to_ocaml (scm_c_primitive_load (String_val (filename))));
}


// Returns the Scheme value '() as an OCaml Scheme value.
CAMLprim value amina_eol () {
  CAMLparam0 ();
  CAMLreturn (amina_to_ocaml (SCM_EOL));
}

/**
  Accepts an OCaml Scheme object x and returns an OCaml boolean value
  that is true iff x represents a string.
*/
CAMLprim value amina_is_string (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_string (amina_from_ocaml (x))));
}

CAMLprim value amina_is_symbol (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_symbol (amina_from_ocaml (x))));
}

CAMLprim value amina_is_number (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_number (amina_from_ocaml (x))));
}

CAMLprim value amina_is_integer (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_integer (amina_from_ocaml (x))));
}

CAMLprim value amina_is_exact_integer (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_exact_integer (amina_from_ocaml (x))));
}

CAMLprim value amina_is_bool (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_bool (amina_from_ocaml (x))));
}

CAMLprim value amina_is_char (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_true (scm_char_p (amina_from_ocaml (x)))));
}

CAMLprim value amina_is_null (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_null (amina_from_ocaml (x))));
}

CAMLprim value amina_is_pair (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_pair (amina_from_ocaml (x))));
}

CAMLprim value amina_is_list (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_to_bool (scm_list_p (amina_from_ocaml (x)))));
}

CAMLprim value amina_is_vector (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_is_vector (amina_from_ocaml (x))));
}

/**
  Accepts an OCaml Scheme object x that represents an integer and
  returns an OCaml integer.
*/
CAMLprim value amina_from_integer (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_long (scm_to_long_long (amina_from_ocaml (x))));
}

CAMLprim value amina_from_double (value x) {
  CAMLparam1 (x);
  CAMLreturn (caml_copy_double (scm_to_double (amina_from_ocaml (x))));
}

CAMLprim value amina_from_bool (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_bool (scm_to_bool (amina_from_ocaml (x))));
}

/**
  Accepts an OCAML Scheme object x that represents a Scheme char and
  returns an OCaml integer that encodes for the same character.
*/
CAMLprim value amina_from_char (value x) {
  CAMLparam1 (x);
  CAMLreturn (Val_int (scm_char_to_integer (amina_from_ocaml (x))));
}

CAMLprim value amina_from_string (value x) {
  CAMLparam1 (x);
  CAMLlocal1 (res);
  char* s = scm_to_locale_string (amina_from_ocaml (x));
  res = caml_copy_string (s);
  free (s);
  CAMLreturn (res);
}

CAMLprim value amina_from_symbol (value x) {
  CAMLparam1 (x);
  CAMLlocal1 (res);
  char* s = scm_to_locale_string (scm_symbol_to_string (amina_from_ocaml (x)));
  res = caml_copy_string (s);
  free (s);
  CAMLreturn (res);
}

/**
  Accepts an OCaml integer and returns it as a Scheme integer.

  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_to_integer (value x) {
  CAMLparam1 (x);
  CAMLreturn (amina_to_ocaml (scm_from_long_long (Long_val (x))));
}

/**
  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_to_double (value x) {
  CAMLparam1 (x);
  CAMLreturn (amina_to_ocaml (scm_from_double (Double_val (x))));
}

/**
  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_to_bool (value x) {
  CAMLparam1 (x);
  CAMLreturn (amina_to_ocaml (scm_from_bool (Bool_val (x))));
}

/**
  Accepts an OCaml string and returns it as a Scheme string.

  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_string_to_string (value x) {
  CAMLparam1 (x);
  CAMLreturn (amina_to_ocaml (scm_from_locale_string (String_val (x))));
}

/**
  Accepts two OCaml Scheme values: x and y; and cons them; and returns
  the result.

  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_cons (value x, value y) {
  CAMLparam2 (x, y);
  CAMLreturn (amina_to_ocaml (scm_cons (amina_from_ocaml (x), amina_from_ocaml (y))));
}

/**
  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_car (value x) {
  CAMLparam1 (x);
  CAMLreturn (amina_to_ocaml (SCM_CAR (amina_from_ocaml (x))));
}

/**
  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_cdr (value x) {
  CAMLparam1 (x);
  CAMLreturn (amina_to_ocaml (SCM_CDR (amina_from_ocaml (x))));
}

/**
  WARNING: you must call `amina_free_scm_value` on the Scheme value returned
  by this function to free it.
*/
CAMLprim value amina_vector_to_list (value x) {
  CAMLparam1 (x);
  CAMLreturn (amina_to_ocaml (scm_vector_to_list (amina_from_ocaml (x))));
}

/**
  The following functions set bindings to the Amina API.
*/

const static char* parse_path_name = "parse-path";

SCM amina_register_parse_path_callback (SCM x) {
  SCM result = amina_from_ocaml (caml_callback (*caml_named_value (parse_path_name), amina_to_ocaml (x)));
  scm_gc_unprotect_object (x);
  return result;
}

CAMLprim void amina_register_parse_path () {
  CAMLparam0 ();
  scm_c_define_gsubr (parse_path_name, 1, 0, 0, &amina_register_parse_path_callback);
  CAMLreturn0;
}

const static char* get_data_aux_name = "get-data-aux";

SCM amina_register_get_data_aux_callback (SCM x) {
  SCM result = amina_from_ocaml (caml_callback (*caml_named_value (get_data_aux_name), amina_to_ocaml (x)));
  scm_gc_unprotect_object (x);
  return result;
}

CAMLprim void amina_register_get_data_aux () {
  CAMLparam0 ();
  scm_c_define_gsubr (get_data_aux_name, 1, 0, 0, &amina_register_get_data_aux_callback);
  CAMLreturn0;
}

const static char* get_data_name = "get-data";

SCM amina_register_get_data_callback (SCM path, SCM json) {
  SCM result = amina_from_ocaml (caml_callback2 (
    *caml_named_value (get_data_name),
    amina_to_ocaml (path),
    amina_to_ocaml (json)
  ));
  scm_gc_unprotect_object (path);
  scm_gc_unprotect_object (json);
  return result;
}

CAMLprim void amina_register_get_data () {
  CAMLparam0 ();
  scm_c_define_gsubr (get_data_name, 1, 0, 1, &amina_register_get_data_callback);
  CAMLreturn0;
}

const static char* call_with_local_context_name = "call-with-local-context";

SCM amina_register_call_with_local_context_callback (SCM f, SCM json) {
  SCM result = amina_from_ocaml (caml_callback2 (
    *caml_named_value (call_with_local_context_name),
    amina_to_ocaml (f),
    amina_to_ocaml (json)
  ));
  scm_gc_unprotect_object (f);
  scm_gc_unprotect_object (json);
  return result;
}

CAMLprim void amina_register_call_with_local_context () {
  CAMLparam0 ();
  scm_c_define_gsubr (call_with_local_context_name, 1, 0, 1, &amina_register_call_with_local_context_callback);
  CAMLreturn0;
}

const static char* num_to_string_name = "num->string";

SCM amina_register_num_to_string_callback (SCM x, SCM args) {
   SCM result = amina_from_ocaml (caml_callback2 (
    *caml_named_value (num_to_string_name),
    amina_to_ocaml (x),
    amina_to_ocaml (args)
  ));
  scm_gc_unprotect_object (x);
  scm_gc_unprotect_object (args);
  return result;
}

CAMLprim void amina_register_num_to_string () {
  CAMLparam0 ();
  scm_c_define_gsubr (num_to_string_name, 1, 0, 1, &amina_register_num_to_string_callback);
  CAMLreturn0;
}

const static char* string_to_num_name = "string->num";

SCM amina_register_string_to_num_callback (SCM x) {
  SCM result = amina_from_ocaml (caml_callback (
    *caml_named_value (string_to_num_name),
    amina_to_ocaml (x)
  ));
  scm_gc_unprotect_object (x);
  return result;
}

CAMLprim void amina_register_string_to_num () {
  CAMLparam0 ();
  scm_c_define_gsubr (string_to_num_name, 1, 0, 0, &amina_register_string_to_num_callback);
  CAMLreturn0;
}

const static char* to_json = "to-json";

SCM amina_register_to_json_callback (SCM x) {
  SCM result = amina_from_ocaml (caml_callback (
    *caml_named_value (to_json),
    amina_to_ocaml (x)
  ));
  scm_gc_unprotect_object (x);
  return result;
}

CAMLprim void amina_register_to_json () {
  CAMLparam0 ();
  scm_c_define_gsubr (to_json, 1, 0, 0, &amina_register_to_json_callback);
  CAMLreturn0;
}

const static char* parse_json = "parse-json";

SCM amina_register_parse_json_callback (SCM x) {
  SCM result = amina_from_ocaml (caml_callback (
    *caml_named_value (parse_json),
    amina_to_ocaml (x)
  ));
  scm_gc_unprotect_object (x);
  return result;
}

CAMLprim void amina_register_parse_json () {
  CAMLparam0 ();
  scm_c_define_gsubr (parse_json, 1, 0, 0, &amina_register_parse_json_callback);
  CAMLreturn0;
}

const static char* get_data_json_string = "get-data-json-string";

SCM amina_register_get_data_json_string_callback (SCM x) {
  SCM result = amina_from_ocaml (caml_callback (
    *caml_named_value (get_data_json_string),
    amina_to_ocaml (x)
  ));
  scm_gc_unprotect_object (x);
  return result;
}

CAMLprim void amina_register_get_data_json_string () {
  CAMLparam0 ();
  scm_c_define_gsubr (get_data_json_string, 1, 0, 0, &amina_register_get_data_json_string_callback);
  CAMLreturn0;
}
