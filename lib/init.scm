#|
  Accepts one argument: n, an integer; and returns a string that
  represents it.

  Note: this function will accept a floating point number as well.
  When passed a real number, it will round the number to its nearest
  integer, and return that integer as a string.
|#
(define (int->string n) (num->string n 0))