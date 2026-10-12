;; Use-case acceptance examples for capture-environment (migrating from
;; MIT-style (the-environment)).  Drafted by deepseek-v4-pro, adjusted.
(cond-expand
 (modules
  (import (chibi)
          (only (chibi test) test-begin test test-end)
          (only (scheme base) open-input-string)))
 (else #f))

(test-begin "capture-environment use cases")

(define (eval-string s env) (eval (read (open-input-string s)) env))

;; 1. Tiny inspector: capture chosen locals, evaluate user expressions.
(define (make-inspector a b)
  (let ((env (capture-environment a b)))
    (lambda (s) (eval-string s env))))
(test 7 ((make-inspector 3 4) "(+ a b)"))

;; 2. eval-in-scope helper called inside a function.
(define (compute-with-offset offset xs)
  (eval-string "(map (lambda (x) (* x offset)) xs)"
               (capture-environment offset xs)))
(test '(3 6 9) (compute-with-offset 3 '(1 2 3)))

;; 3. Expression engine: a handler captures (name args) and evaluates
;; configured expression strings.
(define (make-template-handler name args)
  (let ((env (capture-environment name args)))
    (lambda (s) (eval-string s env))))
(test "Hello, Alice (first)"
      ((make-template-handler "Alice" '("first" "second"))
       "(string-append \"Hello, \" name \" (\" (car args) \")\")"))

;; 4. Assertion that records the captured locals on failure.
(define (make-assertion env names)
  (lambda (expected actual)
    (if (equal? expected actual)
        #t
        (list 'failure expected actual
              (map (lambda (n) (list n (eval n env))) names)))))
(test '(failure 1 2 ((a 1) (b 2) (c 3)))
      (let ((a 1) (b 2) (c 3))
        ((make-assertion (capture-environment a b c) '(a b c)) 1 2)))

;; 5. Callbacks capturing a loop variable: snapshot vs. ordinary closure.
(define (make-callbacks snapshot?)
  (let ((i 0) (cbs '()))
    (for-each
     (lambda (_)
       (let ((env (capture-environment i)))
         (set! cbs (cons (if snapshot? (lambda () (eval 'i env)) (lambda () i))
                         cbs)))
       (set! i (+ i 1)))
     '(a b c))
    (set! i 99)
    (map (lambda (cb) (cb)) (reverse cbs))))
(test '((0 1 2) (99 99 99))
      (list (make-callbacks #t) (make-callbacks #f)))

;; 6. A large buffer is deliberately not captured: invisible to eval.
(define (make-scoped-evaluator big-buffer offset)
  (let ((env (capture-environment offset)))
    (lambda (s) (eval-string s env))))
(define scoped (make-scoped-evaluator (make-vector 1000 42) 5))
(test 15 (scoped "(+ offset 10)"))
(test-end)
