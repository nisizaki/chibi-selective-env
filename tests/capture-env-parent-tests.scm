(cond-expand
 (modules
  (import (chibi) (only (chibi ast) env-cell)
          (only (chibi test) test-begin test test-end)
          (only (scheme base) guard)))
 (else #f))

(test-begin "capture-environment/parent")

(define (raises? thunk)
  (guard (e (#t #t)) (thunk) #f))

;; NOTE: the error tests run first.  After (scheme-report-environment 7)
;; has been created, expansion-time errors raised inside eval are no longer
;; caught by guard in this chibi build (upstream behaviour, unrelated to
;; capture-environment/parent).
;; errors: non-identifier, duplicate, non-environment parent
(define non-id-raises?
  (raises? (lambda () (eval '(capture-environment/parent (null-environment 7) 1) (interaction-environment)))))
(test #t non-id-raises?)
(test #t (raises? (lambda () (let ((x 1)) (capture-environment/parent (null-environment 7) x x)))))
(test #t (raises? (lambda () (let ((x 1)) (capture-environment/parent 5 x)))))

(define top-level-value 7)

;; Which of x / + / if / car / the top-level variable are visible in the
;; result?  (env-cell looks through parents; #t = visible)
(define (probe parent)
  (let* ((x 10) (env (capture-environment/parent parent x)))
    (map (lambda (name) (and (env-cell env name) #t))
         '(x + if car top-level-value))))

(test '(#t #f #t #f #f) (probe (null-environment 7)))
(test (quote (#t #t #t #t #f)) (probe (primitive-environment 7)))
(test '(#t #t #t #t #f) (probe (scheme-report-environment 7)))
(test '(#t #t #t #t #t) (probe (interaction-environment)))

;; the captured variable itself is visible and is a snapshot
(define y 1)
(define env-y (capture-environment/parent (primitive-environment 7) y))
(set! y 2)
(test 1 (eval 'y env-y))

;; parent expression is evaluated once, at capture time
(define count 0)
(define env-c (capture-environment/parent (begin (set! count (+ count 1)) (primitive-environment 7)) y))
(test 1 count)

;; zero ids
(test 3 (eval '(+ 1 2) (capture-environment/parent (primitive-environment 7))))

(test-end)
