(use judge)
(import stx)

(defn mtch [str]
  (tuple/slice (peg/match stx/parser/pattern str 0 :t)))

(test (mtch "") [])

# Symbols and keywords

(test (mtch "abc")
  [{:partial? :maybe
    :source {:column 1 :line 1 :name :t :position 0}
    :type :symbol
    :value "abc"}])

(test (mtch "abc ")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :symbol
    :value "abc"}])

(test (mtch "abc#Hello")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :symbol
    :value "abc"}])

(test (mtch ":abc")
  [{:partial? :maybe
    :source {:column 1 :line 1 :name :t :position 0}
    :type :keyword
    :value "abc"}])

(test (mtch ":abc def")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :keyword
    :value "abc"}
   {:partial? :maybe
    :source {:column 6 :line 1 :name :t :position 5}
    :type :symbol
    :value "def"}])

(test (mtch ":abc\r\ndef")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :keyword
    :value "abc"}
   {:partial? :maybe
    :source {:column 1 :line 2 :name :t :position 6}
    :type :symbol
    :value "def"}])

(test (mtch "0")
  [{:partial? :maybe
    :source {:column 1 :line 1 :name :t :position 0}
    :type :number
    :value 0}])

(test (mtch "0. ")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :number
    :value 0}])

(test (mtch "0xff ")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :number
    :value 255}])

(test (mtch "156.78 ")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :number
    :value 156.78}])

(test (mtch "1x")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :partial? :number-error
    :type :symbol
    :value "1x"}])

(test-error (mtch "1x ") "Invalid number in \"t\" at line 1 column 1")

# Reader Macros

(test (mtch "'")
  [{:partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :quote
    :value {:partial? true}}])

(test (mtch "~x")
  [{:partial? :maybe
    :source {:column 1 :line 1 :name :t :position 0}
    :type :quasiquote
    :value {:partial? :maybe
            :source {:column 2 :line 1 :name :t :position 1}
            :type :symbol
            :value "x"}}])

(test (mtch "~x ")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :quasiquote
    :value {:source {:column 2 :line 1 :name :t :position 1}
            :type :symbol
            :value "x"}}])

(test (mtch "~,x ")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :quasiquote
    :value {:source {:column 2 :line 1 :name :t :position 1}
            :type :unquote
            :value {:source {:column 3 :line 1 :name :t :position 2}
                    :type :symbol
                    :value "x"}}}])

# Tuples

(test (mtch "()")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :ptuple
    :value @[]}])

(test (mtch "(print)")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :ptuple
    :value @[{:source {:column 2 :line 1 :name :t :position 1}
              :type :symbol
              :value "print"}]}])

(test (mtch "(print")
  [{:partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :ptuple
    :value @[{:partial? :maybe
              :source {:column 2 :line 1 :name :t :position 1}
              :type :symbol
              :value "print"}]}])

(test (mtch "[]")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :btuple
    :value @[]}])

(test (mtch "[[]]")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :btuple
    :value @[{:source {:column 2 :line 1 :name :t :position 1}
              :type :btuple
              :value @[]}]}])

(test-error (mtch ")") "Unmatched closing parenthesis in \"t\" at line 1 column 1")
(test-error (mtch " \n\n   #]\n ]") "Unmatched closing square bracket in \"t\" at line 4 column 2")

# Strings

(test (mtch `"`)
  [{:partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value ""}])

(test (mtch `""`)
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value ""}])

(test (mtch `"\n\\`)
  [{:partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\n\\"}])

(test (mtch `"\n\\"`)
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\n\\"}])

(test (mtch `"\x`)
  [{:partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value ""}])

(test (mtch `"\xf`)
  [{:partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value ""}])

(test (mtch `"\xff"`)
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\xff"}])

(test (mtch `"\ufa12"`)
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\ufa12"}])

(test (mtch `"\u0333"`)
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\u0333"}])

(test (mtch `"\U10FFFF"`)
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\U10FFFF"}])

(test (mtch `@"Hello, world!"`)
  [{:source {:column 2 :line 1 :name :t :position 1}
    :type :buffer
    :value "Hello, world!"}])

(test-error (mtch `"\xf"`) "Invalid escape in \"t\" at line 1 column 3")
(test-error (mtch `"\xf `) "Invalid escape in \"t\" at line 1 column 3")
(test-error (mtch `"\u `) "Invalid escape in \"t\" at line 1 column 3")
(test-error (mtch `"\U `) "Invalid escape in \"t\" at line 1 column 3")
(test-error (mtch `"\U00 `) "Invalid escape in \"t\" at line 1 column 3")
(test-error (mtch `"\U00000 `) "Invalid escape in \"t\" at line 1 column 3")
(test-error (mtch `"\u0 `) "Invalid escape in \"t\" at line 1 column 3")
(test-error (mtch `"\u000 `) "Invalid escape in \"t\" at line 1 column 3")

(test-error (mtch `"\UFFFFFF `) "Invalid unicode codepoint in \"t\" at line 1 column 4")
(test-error (mtch `"\U110000 `) "Invalid unicode codepoint in \"t\" at line 1 column 4")

# Long strings
(test (mtch ```
`
```)
  [{:delim "`"
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :long-string
    :value ""}])
#"))

(test (mtch ```
``
```)
  [{:delim "``"
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :long-string
    :value ""}])

(test (mtch ```
``Hello!``
```)
  [{:delim "``"
    :source {:column 1 :line 1 :name :t :position 0}
    :type :long-string
    :value "Hello!"}])

(test (mtch ```
``Hello!\n``
```)
  [{:delim "``"
    :source {:column 1 :line 1 :name :t :position 0}
    :type :long-string
    :value "Hello!\\n"}])

(test (mtch ```
  ``Hello!\n``
```)
  [{:delim "``"
    :source {:column 3 :line 1 :name :t :position 2}
    :type :long-string
    :value "Hello!\\n"}])

(test (mtch ```
  ``
  A line.
  ``
```)
  [{:delim "``"
    :source {:column 3 :line 1 :name :t :position 2}
    :type :long-string
    :value "\n  A line.\n  "}])

# Structs

(test (mtch "{}")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :struct
    :value @[]}])

(test (mtch "{:hello")
  [{:partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :struct
    :value @[]}])

(test (mtch "{:hello :world")
  [{:partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :struct
    :value @[{:source {:column 2 :line 1 :name :t :position 1}
              :type :keyword
              :value "hello"}
             {:partial? :maybe
              :source {:column 9 :line 1 :name :t :position 8}
              :type :keyword
              :value "world"}]}])

(test (mtch "{:hello :world}")
  [{:source {:column 1 :line 1 :name :t :position 0}
    :type :struct
    :value @[{:source {:column 2 :line 1 :name :t :position 1}
              :type :keyword
              :value "hello"}
             {:source {:column 9 :line 1 :name :t :position 8}
              :type :keyword
              :value "world"}]}])

(test-error (mtch "}") "Unmatched closing curly bracket in \"t\" at line 1 column 1")
