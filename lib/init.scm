#|
  Accepts two arguments: f, a lambda expression; and json, a JSON object; sets
  the local JSON context to equal json and calls f.
|#
(define (call-with-local-context f json)
  (push-local-context! json)
  (let [(result (f))]
    (pop-local-context!)
    result))

#|
  Accepts one argument: path, a string that represents a JSON path expression;
  and an optional argument: json, a JSON object.

  When passed only path, this function reads the JSON value referenced by path
  from either the Root or Local JSON contexts.

  When passed json, this function will read a JSON value from json instead of
  the Local context.
|#
(define get-data
  (case-lambda
    ((path) (get-data-aux path))
    ((path json)
      (call-with-local-context
        (lambda () (get-data-aux path))
        json))))

#|
  Accepts one argument: n, an integer; and returns a string that
  represents it.

  Note: this function will accept a floating point number as well.
  When passed a real number, it will round the number to its nearest
  integer, and return that integer as a string.
|#
(define (int->string n) (num->string n 0))