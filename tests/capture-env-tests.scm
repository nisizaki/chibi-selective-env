(cond-expand
 (modules
  (import (chibi)
          (only (chibi test) test-begin test test-error test-end)
          (only (scheme base) guard)))
 (else #f))

(test-begin "capture-environment")

(define (raises? thunk)
  (guard (e (#t #t)) (thunk) #f))

(define (make-env)
  (let ((huge-buffer (make-vector 1000 0))
        (x 10)
        (y 20))
    (capture-environment x y)))

(define env (make-env))
(test 30 (eval (quote (+ x y)) env))
(test-error (eval (quote huge-buffer) env))
(test 3 (eval (quote (+ 1 2)) (capture-environment)))

;; captured values are shared, but the variable binding is a snapshot
(define v (vector 1))
(define env-v (capture-environment v))
(vector-set! v 0 42)
(test 42 (eval (quote (vector-ref v 0)) env-v))
(define z 1)
(define env-z (capture-environment z))
(set! z 2)
(test 1 (eval (quote z) env-z))
(test 2 z)

;; independent captures
(define a 1)
(define env-a1 (capture-environment a))
(set! a 100)
(define env-a2 (capture-environment a))
(test 1 (eval (quote a) env-a1))
(test 100 (eval (quote a) env-a2))

;; nested scopes and procedure values
(define (f p)
  (let ((q (* p 2)))
    (let loop ((i 0) (acc (quote ())))
      (if (= i 3)
          (capture-environment p q acc)
          (loop (+ i 1) (cons i acc))))))
(define env-f (f 5))
(test (list 5 10 (list 2 1 0)) (eval (quote (list p q acc)) env-f))
(test-error (eval (quote i) env-f))
(define env-fn (let ((n 10)) (let ((g (lambda (x) (+ n x)))) (capture-environment g))))
(test 15 (eval (quote (g 5)) env-fn))

;; errors
(test-error (eval (quote (let ((x 1)) (capture-environment x x))) (interaction-environment)))
;; (raises? is bound outside of test: expansion-time errors raised inside a
;; test form are not visible to a guard nested in it)
(define non-id-raises?
  (raises? (lambda () (eval (quote (capture-environment 1)) (interaction-environment)))))
(test #t non-id-raises?)
;; non-identifier arguments are rejected before being evaluated
(define side-effect #f)
(define non-id-expr-raises?
  (raises? (lambda () (eval (quote (capture-environment (set! side-effect #t))) (interaction-environment)))))
(test #t non-id-expr-raises?)
(test #f side-effect)
;; unbound variables are an error when the captured value is computed
(define (capture-later) (capture-environment later-var))
(define unbound-raises? (raises? capture-later))
(test #t unbound-raises?)

(test-end)
