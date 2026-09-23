#include <libguile.h>
#include <caml/mlvalues.h>

/**
  Accepts a pointer to a Guile scheme object and returns an OCaml
  reference to that object.

  WARNING: you MUST call `scm_gc_protect_object` on the Guile Scheme
  object before passing it to OCaml. See `amina_free_scm_value`.
*/
value amina_to_ocaml (SCM x);
