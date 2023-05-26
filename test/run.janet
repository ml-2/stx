(use judge)
(use ./util)
(import stx)

# NOTE START: Do not add lines here, since this will break the line numbers in the error messages. #

(test-error (stx/sourcemap/run '(```
\\
```)) "Invalid syntax in \"test/run.janet\" at line 8 column 1")

(test-error (stx/sourcemap/run '(```
symbol-doesnt-exist
```)) @"<anonymous>:12:1: compile error: unknown symbol symbol-doesnt-exist\n")

(test-error (stx/sourcemap/run '(```

  ("")
```)) @"<anonymous>:17:3: compile error: \"\" expects 1 argument, got 0\n")

(stx/sourcemap/run '(```
(def syntactic \'[])
```))

(test (as syntactic)
  {:column 18
   :depth 0
   :line 21
   :name "test/run.janet"
   :value []})

(test-error (stx/sourcemap/run '(```
({[
```)) "Unterminated btuple value in file \"test/run.janet\" at line 32 column 3")

(test-error (stx/sourcemap/run '(```
({[5x
```)) "Invalid number 5x in file \"test/run.janet\" at line 36 column 4")

(test-error (stx/sourcemap/run '(```
({[hello
```)) "Unterminated btuple value in file \"test/run.janet\" at line 40 column 3")

(test-error (stx/sourcemap/run '(```
\'(1 2 3
```)) "Unterminated ptuple value in file \"test/run.janet\" at line 44 column 3")

(test-error (stx/sourcemap/run '(```
\([1 2 3
```)) "Unterminated btuple value in file \"test/run.janet\" at line 48 column 3")

(test-error (stx/sourcemap/run '(```
\(
```)) "Unterminated ptuple value in file \"test/run.janet\" at line 52 column 2")

# NOTE END

(test-error (stx/sourcemap/run '(```
(error "the message")
```)) "the message")

# Import

(def hidden-symbol true)

(stx/init)
(import ./imp)

(test (as imp/syntactic)
  {:column 18
   :depth 0
   :line 2
   :name "test/imp.janet.stx"
   :value [{:column 19
            :depth 0
            :line 2
            :name "test/imp.janet.stx"
            :value a-symbol}]})

(test (= stx/new imp/my-stx-new) true)

(test-error (import ./imp-err) "Unterminated stx/quote value in file \"test/imp-err.janet.stx\" at line 2 column 1")

