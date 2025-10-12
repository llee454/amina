(add-to-load-path (dirname (current-filename)))
(import
  (rnrs (6))
  (import_example ((>= 1)))
)

(define author "Larry D. Lee Jr.")

(define (get-pi-multiple x) (* (example-fn x) (string->num (get-data "root.pi"))))

(define (test-to-json)
  (to-json '((hi . 1.23) (hello . "be back"))))
