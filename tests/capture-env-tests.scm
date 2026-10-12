(cond-expand
 (modules
  (import (chibi)
          (only (chibi test) test-begin test test-error test-end)))
 (else #f))

(test-begin "capture-environment")

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
(test-error (eval (quote (capture-environment 1)) (interaction-environment)))

(test-end)
