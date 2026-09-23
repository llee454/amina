; This library is the entry point into the Amina Scheme library.
; It loads the necessary extensions and exposes functions defined in the
; Guile Amina extension.
;
; Usage
;
; $ GUILE_EXTENSIONS_PATH='./guile' GUILE_LOAD_PATH='./guile' rlwrap guile
; (use-modules (amina))
(define-module (amina)
  #:version (1 0 0)
  #:use-module ((rnrs) #:version (6))
  #:export (
    set-root-context!
    rewrite-string
    parse-path
    get-data-aux
    get-data
    call-with-local-context
    num->string
    string->num
    to-json
    parse-json
    get-data-json-string
  ))

(load-extension "guile_amina.so" "init")

; Accepts a list that represents a JSON object and sets it as the root context.
(define (set-root-context! json)
  (amina-set-root-context json))

; Accepts an Amina template string, evaluates it, and returns the result as
; a string.
(define (rewrite-string str)
  (amina-rewrite-string str))
