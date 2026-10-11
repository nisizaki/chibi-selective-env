
(define-library (srfi 16)
  (export case-lambda)
  (import (chibi))
  (begin
    ;; Macro generating the actual arity-checking cases
    (define-syntax %case
      (syntax-rules ()
        ((%case (args ...) len n p ((params ...) . body) . rest)
         (if (= len (length '(params ...)))
             (apply (lambda (params ...) . body) args ...)
             (%case (args ...) len 0 () . rest)))
        ((%case (args ...) len n (p ...) ((x . y) . body) . rest)
         (%case (args ...) len (+ n 1) (p ... x) (y . body) . rest))
        ((%case (args ...) len n (p ...) (y . body) . rest)
         (if (>= len n)
             (apply (lambda (p ... . y) . body) args ...)
             (%case (args ...) len 0 () . rest)))
        ((%case args len n p)
         (error "case-lambda: no cases matched"))))
    ;; Helper for the case-lambda with inspectable minimal arity
    (define-syntax %case-lambda
      (syntax-rules ()
        ;; Walk args until common ones run out
        ((%case-lambda (shortest ...) ((arg . args) ...) clauses ...)
         (%case-lambda (shortest ... (arg ...)) (args ...) clauses ...))
        ;; When ran out, generate a lambda with shortest args followed
        ;; by rest arg
        ;; This (arg . _) is here because we need to “flatten” the
        ;; nested list
        ((%case-lambda ((arg . _) ...) non-parsed-args clauses ...)
         (lambda (arg ... . rest)
           (let ((len (+ (length '(arg ...))
                         (length rest))))
             (%case (arg ... rest) len 0 () clauses ...))))))
    (define-syntax case-lambda
      (syntax-rules ()
        ;; Recursive case, walking required args
        ((case-lambda ((args ... . rest) body ...) ...)
         (%case-lambda () ((args ...) ...) ((args ... . rest) body ...) ...))
        ;; Terminal case for case-lambda with atypical arglists, like
        ;; rest-symbol-only arglists.
        ((case-lambda (args body ...) ...)
         (lambda rest-arg
           (let ((len (length rest-arg)))
             (%case (rest-arg) len 0 () (args body ...) ...))))))))
