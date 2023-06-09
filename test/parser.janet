(use judge)
(use ./util)
(import stx)

(defn consume
  "Consume one byte at a time. This helps detect errors in the partial parsing functionality."
  [parser str]
  (each byte str
    (:consume parser (string/from-bytes byte))))

(def parser (stx/parser/new))
(consume parser " hello")
(test (:has-more parser) false)
(:eof parser)
(test (:has-more parser) true)
(test (:produce parser) hello)

(def parser (stx/parser/new))
(consume parser "#Hello, world!\n")
(test (:has-more parser) false)
(consume parser `\'hello `)
(test (:has-more parser) true)
(def syntax (:produce parser))
(test (stx/line syntax) 2)
(test (stx/column syntax) 3)
(test (stx/value syntax) hello)
(test (:has-more parser) false)

(def parser (stx/parser/new))
(consume parser "\n  ``\n  Hello1\n  ``")
(test (:produce parser) "Hello1")
(consume parser "\n ``\n  Hello2\n  ``")
(test (:produce parser) " Hello2\n ")
(consume parser "\n  ``\nHello3\n  ``")
(test (:produce parser) "Hello3\n  ")
(consume parser "\n  @``\n   Hello4\n   ``")
(test (:produce parser) @"Hello4")
(consume parser "\n @``\n   Hello5\n   ``")
(test (:produce parser) @" Hello5\n ")
(consume parser "\n @``\nHello6\n  ``")
(test (:produce parser) @"Hello6\n  ")
(test (:has-more parser) false)

(def parser (stx/parser/new))
(consume parser `\(or 3 5)`)
(def result (:produce parser))
(test (result 0) or)
(test (stx/value (result 1)) 3)
(test (stx/value (result 2)) 5)
(test (stx/line (result 2)) 1)
(test (stx/column (result 2)) 8)

(def parser (stx/parser/new))
(consume parser "\n\\'\\```\nHello, world!\n```")
(def result (:produce parser))
(test (stx/value result) "\nHello, world!\n")
(test (stx/line result) 2)
(test (stx/column result) 7)
(test (:has-more parser) false)

(def parser (stx/parser/new))
(consume parser "hello#world")
(test (:produce parser) hello)
(:eof parser)
(test (:has-more parser) false)

(def parser (stx/parser/new))
(consume parser "@[] @[1] @[1 2 3] @[```\nhello\n``` world]")
(test (:produce parser) @[])
(test (:produce parser) @[1])
(test (:produce parser) @[1 2 3])
(test (:produce parser) @["hello" world])

(def parser (stx/parser/new))
(consume parser "@{} @{1 2} @{1 2 3 4} @{```\nhello\n``` world}")
(test (:produce parser) @{})
(test (:produce parser) @{1 2})
(test (:produce parser) @{1 2 3 4})
(test (:produce parser) @{"hello" world})

(def parser (stx/parser/new))
(consume parser `\'\(or 3 5)`)
(def result (:produce parser))
(test (as result)
  {:column 3
   :depth 0
   :line 1
   :name "test/parser.janet"
   :value [{:column 5
            :depth 0
            :line 1
            :name "test/parser.janet"
            :value or}
           {:column 8
            :depth 1
            :line 1
            :name "test/parser.janet"
            :value 3}
           {:column 10
            :depth 1
            :line 1
            :name "test/parser.janet"
            :value 5}]})
(test (tuple/sourcemap (stx/value result)) [1 3])
(test (stx/sourcemap result) [1 3])
(test (as (stx/unwrap* result))
  [or
   {:column 8
    :depth 0
    :line 1
    :name "test/parser.janet"
    :value 3}
   {:column 10
    :depth 0
    :line 1
    :name "test/parser.janet"
    :value 5}])
