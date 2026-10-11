(define-library (srfi 16 test)
  (export run-tests)
  (import (chibi) (chibi test) (chibi ast) (srfi 16))
  (begin
    (define (run-tests)
      (define plus
        (case-lambda 
         (() 0)
         ((x) x)
         ((x y) (+ x y))
         ((x y z) (+ (+ x y) z))
         (args (apply + args))))
      (define print
        (case-lambda
         (()
          (display ""))
         ((arg)
          (display arg))
         ((arg . args)
          (display arg)
          (display " ")
          (apply print args))))
      (define (print-to-string . args)
        (let ((out (open-output-string))
              (old-out (current-output-port)))
          (dynamic-wind
            (lambda () (current-output-port out))
            (lambda () (apply print args))
            (lambda () (current-output-port old-out)))
          (get-output-string out)))

      (test-begin "srfi-16: case-lambda")

      (test 0 (plus))
      (test 1 (plus 1))
      (test 6 (plus 1 2 3))
      (test-error ((case-lambda ((a) a) ((a b) (* a b))) 1 2 3))

      (test "" (print-to-string))
      (test "hi" (print-to-string 'hi))
      (test "hi there world" (print-to-string 'hi 'there 'world))

      ;; Testing smart inspectable minimal arity

      ;; Test rest arg presence resulting in fully variadic lambda
      (test 0 (procedure-arity (case-lambda (a 1))))
      (test 0 (procedure-arity (case-lambda ((a b c) 1) (a 1))))
      (test 0 (procedure-arity (case-lambda (a 1) ((a b c) 1))))

      ;; Test shortest arglist of 0, 1, and 2
      (test 0 (procedure-arity (case-lambda (() 1) ((a b) 1) ((a b c) 1))))
      (test 0 (procedure-arity (case-lambda ((a b c) 1) (() 1) ((a b) 1))))
      (test 1 (procedure-arity (case-lambda ((a) 1) ((a b) 1) ((a b c) 1))))
      (test 1 (procedure-arity (case-lambda ((a) 1) ((a b c) 1) ((a b) 1))))
      (test 2 (procedure-arity (case-lambda ((a b) 1) ((a b c) 1))))
      (test 2 (procedure-arity (case-lambda ((a b c) 1) ((a b) 1))))

      ;; Minimal arity + rest
      (test 1 (procedure-arity (case-lambda ((a . c) 1) ((a b) 1))))
      (test 2 (procedure-arity (case-lambda ((a b) 1) ((a b . c) 1))))
      (test 2 (procedure-arity (case-lambda ((a b . c) 1) ((a b) 1))))
      (test 0 (procedure-arity (case-lambda ((a b . c) 1) ((a b) 1) (x 1))))

      (test-end))))
