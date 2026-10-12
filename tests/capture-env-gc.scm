;; GC check: an uncaptured large object must be collectable while a
;; capture-environment result is alive; a captured one must stay alive.
(import (chibi) (chibi weak) (chibi ast) (only (chibi test) test-begin test test-end))

(define (make-case capture-huge?)
  (let* ((huge (make-vector 1000000 0))
         (x 42)
         (eph (make-ephemeron huge #t))
         (env (if capture-huge?
                  (capture-environment x huge)
                  (capture-environment x))))
    (cons env eph)))

(define (collected? capture-huge?)
  (let ((c (make-case capture-huge?)))
    (gc) (gc)
    (list (ephemeron-broken? (cdr c))
          (eval (quote x) (car c)))))

(test-begin "capture-environment gc")
(test (list #t 42) (collected? #f))
(test (list #f 42) (collected? #t))
(test-end)
