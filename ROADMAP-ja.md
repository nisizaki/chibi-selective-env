# Chibi-Scheme における `capture-environment` 実装方針

## 1. 目的と仕様

* **構文**: `(capture-environment <var> ...)`
* **セマンティクス**:
  * 構文（Core Form）として扱い、引数に指定された識別子 `<var> ...` のみを対象とする。
  * 実行時に各変数の現在の評価値を抽出し、シンボルと値の対応関係を保持する独立した環境オブジェクト（または連想リスト構造）をヒープに割り当てて返す。
  * 生成された環境は `(eval expr env)` の第2引数として渡すことができる。
  * 対象外の局所変数はヒープ退避せず、スタック／レジスタに留めてGCや実行効率のゼロオーバーヘッドを担保する。

---

## 2. 影響範囲と対象ファイル

* **`include/chibi/vm.h`**: 新規バイトコード命令（Opcode）の定数定義
* **`chibi/compile.scm`**: コア構文の解析、変数ルックアップ、バイトコード生成
* **`vm.c`**: 新規 Opcode の実行ループ処理、環境オブジェクトの生成
* **`eval.c`**: 取り出した環境を `eval` が解決できるようにするためのハンドリング（必要に応じて）

---

## 3. ステップ別作業手順

### Step 1: 新規オペコードの定義 (`include/chibi/vm.h`)

VM の命令列に `OP_CAPTURE_ENV` を追加する。

```c
/* include/chibi/vm.h */
enum sexp_opcode_names {
  /* 既存のオペコード ... */
  SEXP_OP_RESERVE,
  SEXP_OP_PUSH,
  /* ... */
  SEXP_OP_CAPTURE_ENV,  /* 新規追加: 指定スロットから限定環境を構築 */
  /* ... */
};
```

---

### Step 2: コンパイラへの構文追加 (`chibi/compile.scm`)

コンパイラの構文解析器に `capture-environment` を追加し、各変数の束縛情報（スタックインデックスや静的深さ）を特定する。

1. **特殊形式の登録**:
```scheme
;; core-form として登録
(define-core-form 'capture-environment compile-capture-environment)
```

2. **コンパイル処理の実装**:
* 指定されたシンボルリスト `(v1 v2 ...)` を現在のコンパイル時環境 `env` から検索（`lookup`）する。
* 各変数がローカル変数（スタック上の相対オフセット）か、クロージャの自由変数かを判定。
* オペランドとして `((symbol1 . slot1) (symbol2 . slot2) ...)` をエンコードしたバイトコードを出力する。

```scheme
(define (compile-capture-environment src env)
  (let* ((vars (cdr src))
         (bindings
          (map (lambda (var)
                 (let ((b (lookup env var)))
                   (if (not b)
                       (error "capture-environment: unbound variable" var)
                       (cons var (binding-index b)))))
               vars)))
    ;; バイトコード命令列の発行
    (emit OP_CAPTURE_ENV bindings)))
```

---

### Step 3: VM 実行ループへの処理追加 (`vm.c`)

VM のディスパッチループ（`sexp_apply` / `sexp_run`）に `SEXP_OP_CAPTURE_ENV` のハンドラを追加する。

```c
/* vm.c 内のバイトコードディスパッチ部 */
case SEXP_OP_CAPTURE_ENV: {
  sexp bindings = SEXP_OP_ARG(pc); // コンパイラが埋め込んだメタデータ
  sexp new_env = sexp_make_null(); // または sexp_alloc_env(ctx)

  /* 指定された各シンボルと、VMスタック上のスロット値をペアにして環境を構築 */
  for (sexp p = bindings; sexp_pairp(p); p = sexp_cdr(p)) {
    sexp pair = sexp_car(p);
    sexp sym = sexp_car(pair);
    sexp_uint_t slot = sexp_to_uint(sexp_cdr(pair));

    /* スタック上の現在値を取得 */
    sexp val = stack[fp + slot];

    /* 新しい環境レコードに (sym . val) を束縛 */
    new_env = sexp_env_define(ctx, new_env, sym, val);
  }

  /* 戻り値レジスタ/スタックトップに新環境を格納 */
  result = new_env;
  SEXP_NEXT();
}
```

---

### Step 4: `eval` との結合確認 (`tests/`)

実装した `capture-environment` をテストスクリプトで評価する。

```scheme
(import (scheme base)
        (scheme write)
        (scheme eval))

(let ((huge-data (make-vector 1000000 0)) ; キャプチャされない変数
      (x 10)
      (y 20))
  (let ((env (capture-environment x y)))
    ;; 1. 指定した変数のみが eval で参照できること
    (display (eval '(+ x y) env)) ; => 30
    (newline)

    ;; 2. 指定していない変数は未定義エラーになること
    ;; (eval 'huge-data env) ; => error: undefined variable
    ))
```

---

## 4. 検証とチューニングの観点

1. **エスケープ状況の確認**:
   * `huge-data` がスタックから即座にGC回収可能となっているかを、ヒーププロファイラまたは `(gc)` 呼び出し後のアロケーション計測で確認。
2. **ミュータビリティ（可変化）の扱い**:
   * 初期プロトタイプでは「環境取り出し時の値のスナップショット（Immutable）」として設計し、Box化やライトバリアのオーバーヘッドを避ける。
   * `(eval '(set! x 99) env)` を許す必要がある場合は、対象スロットを `sexp_ref` 参照セル（Box）に昇格させるコンパイラパスを後から検討する。
