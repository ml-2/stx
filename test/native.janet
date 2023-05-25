(use judge)
(use ./util)
(import stx)

(test (stx/name (stx/new "t" 1 1 {})) "t")
(test (stx/line (stx/new "t" 3 7 {})) 3)
(test (stx/column (stx/new "t" 3 7 {})) 7)
(test (stx/value (stx/new "t" 3 7 {})) {})
(test (stx/line (stx/new "t" math/int32-max 7 {})) 2147483647)
(test-error (stx/line (stx/new "t" (inc math/int32-max) 7 {}))
            "bad slot #1, expected 32 bit signed integer, got 2147483648")
(test-error (stx/line (stx/new "t" 7 (inc math/int32-max) {}))
            "bad slot #2, expected 32 bit signed integer, got 2147483648")

(test (stx/name (unmarshal (marshal (stx/new "j" 4 6 {})))) "j")
(test (stx/line (unmarshal (marshal (stx/new "j" 4 6 {})))) 4)
(test (stx/column (unmarshal (marshal (stx/new "j" 4 6 {})))) 6)
(test (stx/value (unmarshal (marshal (stx/new "j" 4 6 {})))) {})

(test (stx/unwrap (stx/new "j" 4 6 {})) {})
(test (stx/unwrap {}) {})
(test (stx/stx? (stx/unwrap (stx/new "j" 4 6 {} 1))) true)
(test (stx/stx? (stx/unwrap (stx/unwrap (stx/new "j" 4 6 {} 1)))) false)

(test (stx/sourcemap (stx/new "j" 4 6 {})) [4 6])

(test (as (stx/keep (stx/new "j" 4 6 {}) "hello"))
  {:column 6 :depth 0 :line 4 :name "j" :value "hello"})

(test (stx/or) nil)
(test (stx/or "A") nil)
(test (stx/or "A" "B") nil)
(test (stx/as-struct (stx/or (stx/new "a" 1 2 "A"))) {:column 2 :depth 0 :line 1 :name "a"})
(test (stx/as-struct (stx/or (stx/new "a" 1 2 "A") "B")) {:column 2 :depth 0 :line 1 :name "a"})
(test (stx/as-struct (stx/or (stx/new "a" 1 2 "A") (stx/new "b" 3 4 "B"))) {:column 2 :depth 0 :line 1 :name "a"})
(test (stx/as-struct (stx/or "A" (stx/new "b" 3 4 "B"))) {:column 4 :depth 0 :line 3 :name "b"})

(test (= (stx/new "a" 1 2 "A") (stx/new "a" 1 2 "A")) true)
(test (= (stx/new "a" 1 2 "A") (stx/new "a" 1 2 "B")) false)
(test (not= (stx/new "a" 1 2 "A") (stx/new "a" 1 3 "A")) true)
(test (not= (stx/new "a" 1 2 "A") (stx/new "a" 3 2 "A")) true)
(test (not= (stx/new "a" 1 2 "A") (stx/new "C" 1 2 "A")) true)
(test (not= (stx/new "a" 1 2 "A") (stx/new "a" 1 2 "A" 1)) true)

(test (= (hash (stx/new "a" 1 2 "A")) (hash (stx/new "a" 1 2 "A"))) true)
(test (= (hash (stx/new "a" 1 2 "A")) (hash (stx/new "a" 1 2 "B"))) false)
(test (= (hash (stx/new "a" 1 2 "A")) (hash (stx/new "a" 1 3 "A"))) false)
(test (= (hash (stx/new "a" 1 2 "A")) (hash (stx/new "a" 4 2 "A"))) false)
(test (= (hash (stx/new "a" 1 2 "A")) (hash (stx/new "X" 1 2 "A"))) false)
(test (= (hash (stx/new "a" 1 2 "A")) (hash (stx/new "a" 1 2 "A" 1))) false)

(test (stx/unwrap* (stx/new :j 4 6 {(stx/new :a 2 3 :5) [(stx/new :b 3 5 7)]}))
      {:5 (7)})
(test (as (stx/unwrap* (stx/new :j 4 6 {(stx/new :a 2 3 :5) [(stx/new :b 3 5 7 1)]})))
  {:5 [{:column 5
        :depth 0
        :line 3
        :name :b
        :value 7}]})
