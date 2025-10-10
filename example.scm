(add-to-load-path (dirname (current-filename)))
(import
  (rnrs (6))
  (import_example))

(define author "Larry D. Lee Jr.")

(define (get-pi-multiple x) (* (example-fn x) (string->num (get-data "root.pi"))))