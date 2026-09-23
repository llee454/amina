#include <math.h>

#include <caml/callback.h>
#include <caml/mlvalues.h>
#include <caml/memory.h> // CAMLreturn
#include <caml/alloc.h> // caml_copy

#include <libguile.h>
#include "../amina_guile/amina_guile.h"

/*
  Returns an array of strings that contains the arguments passed to the
  current program.
*/
char** get_argv () {
  SCM args = scm_program_arguments ();
  int args_len = scm_to_int (scm_length (args));
  char** argv = calloc (args_len + 1, sizeof (SCM));
  SCM arg = scm_car (args);
  for (size_t i = 0; i < args_len; i ++, args = scm_cdr (args)) {
    argv[i] = scm_to_locale_string (arg);
  }
  return argv;
}

/*
  Accepts a string that represents an Amina expression and returns the
  evaluated result.
*/
SCM amina_rewrite_string (SCM str) {
  return scm_from_locale_string (String_val (caml_callbackN (
    *caml_named_value ("amina_rewrite_string"), 1, (value[]) {
      caml_copy_string (scm_to_locale_string (str))
    }
  )));
}

SCM amina_set_root_context (SCM json) {
  caml_callback (*caml_named_value ("amina_set_root_context"), amina_to_ocaml (json));
  return SCM_EOL;
}

/*
  Initializes the guile extension.
*/
void init () {
  caml_startup (get_argv ());
  scm_c_define_gsubr ("amina-rewrite-string", 1, 0, 0, amina_rewrite_string);
  scm_c_define_gsubr ("amina-set-root-context", 1, 0, 0, amina_set_root_context);
}
