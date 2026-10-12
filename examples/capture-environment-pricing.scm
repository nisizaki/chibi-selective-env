;; Uses capture-environment/parent with a primitive-environment parent, so
;; top-level definitions of the program are NOT visible to the rules.
;; Example 1-a: configurable pricing rules, evaluated in a captured scope.
;; Rules are data (strings); each rule sees only the order fields that were
;; captured, not the local state of the surrounding function.
(import (chibi) (scheme base) (scheme write))

(define global-secret "top-level-secret")   ; top-level names stay visible!

(define rules
  '(("subtotal"    . "(* price qty)")
    ("discount"    . "(if (>= qty 10) (* 0.1 (* price qty)) 0)")
    ("total"       . "(- (* price qty) (if (>= qty 10) (* 0.1 (* price qty)) 0))")
    ("leak-local"  . "local-secret")
    ("leak-global" . "global-secret")))

(define (eval-string s env) (eval (read (open-input-string s)) env))

;; The scope for the rules is built from exactly the order fields.
(define (apply-rules name price qty)
  (let* ((local-secret "local-secret-value")   ; not captured => invisible
         (env (capture-environment/parent (primitive-environment 7) name price qty)))
    (map (lambda (rule)
           (cons (car rule)
                 (guard (e (#t 'error))
                   (eval-string (cdr rule) env))))
         rules)))

(write (apply-rules "widget" 200 12)) (newline)
(write (apply-rules "gadget" 50 2))   (newline)
