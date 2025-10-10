(library (import_example (1 0 0))
  (export example-fn)
  (import (rnrs (6)))

  (define (example-fn x) (+ x 1))
)
