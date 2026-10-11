# Chibi-Scheme: Selective Environment Reification (`capture-environment`)

An experimental fork of [Chibi-Scheme](https://github.com/ashinn/chibi-scheme) implementing selective, bounded environment reification (`capture-environment`) to reconcile first-class environments with compiler optimizations and garbage collection hygiene.

---

## Background & Motivation

In traditional Scheme implementations, facilities like `(the-environment)` capture the entire current lexical context into a first-class object. While expressive, this approach introduces significant architectural and runtime drawbacks:

1. **GC Spurious Retention (Memory Leaks)**: Capturing the entire lexical frame and its parent scope chain transitively retains unused, massive objects in the heap.
2. **Loss of Liveness Analysis**: The compiler cannot determine variable last-uses, preventing early register reuse and stack slot reclamation.
3. **Violation of the Zero-Overhead Principle**: Code that does not utilize reflection is penalized by conservative stack/heap management and symbol table retention.

This project implements **selective lexical environment reification**:
```scheme
(capture-environment <identifier> ...)
```
By explicitly enumerating the target variables at compile time, the implementation preserves the zero-overhead principle for uncaptured variables while reifying a compact, independent environment record usable with `(eval expr env)`.

---

## Syntax & Semantics

### `(capture-environment <var> ...)`

* **Form**: Core Syntax (Special Form)
* **Arguments**: A list of statically bound identifiers in the current scope.
* **Return Value**: A first-class environment object containing only the specified identifier-value bindings.
* **Behavior**:
  * Unlisted variables remain untouched on the VM stack/registers and do not escape to the heap.
  * Parent environments are disconnected, avoiding transitive retention of outer scopes.
  * The resulting environment can be passed directly as the second argument to R7RS `eval`.

### Example

```scheme
(import (scheme base)
        (scheme write)
        (scheme eval))

(let ((huge-buffer (make-vector 10000000 0)) ; Not retained
      (x 10)
      (y 20))
  (let ((env (capture-environment x y)))
    ;; 1. Captured variables are accessible via eval
    (display (eval '(+ x y) env)) ; => 30
    (newline)

    ;; 2. Uncaptured variables are strictly undefined
    ;; (eval 'huge-buffer env) ; => error: undefined identifier: huge-buffer
    ))
