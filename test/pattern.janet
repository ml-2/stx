(use judge)
(import stx)

(defn mtch [str]
  (tuple/slice (peg/match stx/parser/pattern str 0 :t)))

(test (mtch "") [])

# Symbols and keywords

(test (mtch "abc")
  [{:end 3
    :partial? :maybe
    :source {:column 1 :line 1 :name :t :position 0}
    :type :symbol
    :value "abc"}])

(test (mtch "abc ")
  [{:end 3
    :source {:column 1 :line 1 :name :t :position 0}
    :type :symbol
    :value "abc"}])

(test (mtch "abc#Hello")
  [{:end 3
    :source {:column 1 :line 1 :name :t :position 0}
    :type :symbol
    :value "abc"}])

(test (mtch ":abc")
  [{:end 4
    :partial? :maybe
    :source {:column 1 :line 1 :name :t :position 0}
    :type :keyword
    :value "abc"}])

(test (mtch ":abc def")
  [{:end 4
    :source {:column 1 :line 1 :name :t :position 0}
    :type :keyword
    :value "abc"}
   {:end 8
    :partial? :maybe
    :source {:column 6 :line 1 :name :t :position 5}
    :type :symbol
    :value "def"}])

(test (mtch ":abc\r\ndef")
  [{:end 4
    :source {:column 1 :line 1 :name :t :position 0}
    :type :keyword
    :value "abc"}
   {:end 9
    :partial? :maybe
    :source {:column 1 :line 2 :name :t :position 6}
    :type :symbol
    :value "def"}])

(test (mtch "0")
  [{:end 1
    :partial? :maybe
    :source {:column 1 :line 1 :name :t :position 0}
    :type :number
    :value 0}])

(test (mtch "0. ")
  [{:end 2
    :source {:column 1 :line 1 :name :t :position 0}
    :type :number
    :value 0}])

(test (mtch "0xff ")
  [{:end 4
    :source {:column 1 :line 1 :name :t :position 0}
    :type :number
    :value 255}])

(test (mtch "156.78 ")
  [{:end 6
    :source {:column 1 :line 1 :name :t :position 0}
    :type :number
    :value 156.78}])

(test (mtch "1x")
  [{:end 2
    :source {:column 1 :line 1 :name :t :position 0}
    :partial? :number-error
    :type :symbol
    :value "1x"}])

(test-error (mtch "1x ") "Invalid number in \"t\" at line 1 column 1")

# Reader Macros

(test (mtch "'")
  [{:end 1
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :quote
    :value {:end 1
            :partial? true
            :source {:column 1 :line 1 :name :t :position 0}
            :type :ptuple
            :value @[{:end 1
                      :partial? true
                      :source {:column 1 :line 1 :name :t :position 0}
                      :type :symbol
                      :value "quote"}
                     {:partial? true}]}}])

(test (mtch "~x")
  [{:end 2
    :partial? :maybe
    :source {:column 1 :line 1 :name :t :position 0}
    :type :quasiquote
    :value {:end 2
            :partial? :maybe
            :source {:column 1 :line 1 :name :t :position 0}
            :type :ptuple
            :value @[{:end 2
                      :partial? :maybe
                      :source {:column 1 :line 1 :name :t :position 0}
                      :type :symbol
                      :value "quasiquote"}
                     {:end 2
                      :partial? :maybe
                      :source {:column 2 :line 1 :name :t :position 1}
                      :type :symbol
                      :value "x"}]}}])

(test (mtch "~x ")
  [{:end 2
    :source {:column 1 :line 1 :name :t :position 0}
    :type :quasiquote
    :value {:end 2
            :source {:column 1 :line 1 :name :t :position 0}
            :type :ptuple
            :value @[{:end 2
                      :source {:column 1 :line 1 :name :t :position 0}
                      :type :symbol
                      :value "quasiquote"}
                     {:end 2
                      :source {:column 2 :line 1 :name :t :position 1}
                      :type :symbol
                      :value "x"}]}}])

(test (mtch "~,x ")
  [{:end 3
    :source {:column 1 :line 1 :name :t :position 0}
    :type :quasiquote
    :value {:end 3
            :source {:column 1 :line 1 :name :t :position 0}
            :type :ptuple
            :value @[{:end 3
                      :source {:column 1 :line 1 :name :t :position 0}
                      :type :symbol
                      :value "quasiquote"}
                     {:end 3
                      :source {:column 2 :line 1 :name :t :position 1}
                      :type :unquote
                      :value {:end 3
                              :source {:column 2 :line 1 :name :t :position 1}
                              :type :ptuple
                              :value @[{:end 3
                                        :source {:column 2 :line 1 :name :t :position 1}
                                        :type :symbol
                                        :value "unquote"}
                                       {:end 3
                                        :source {:column 3 :line 1 :name :t :position 2}
                                        :type :symbol
                                        :value "x"}]}}]}}])

# Tuples

(test (mtch "()")
  [{:end 2
    :source {:column 1 :line 1 :name :t :position 0}
    :type :ptuple
    :value @[]}])

(test (mtch "(print)")
  [{:end 7
    :source {:column 1 :line 1 :name :t :position 0}
    :type :ptuple
    :value @[{:end 6
              :source {:column 2 :line 1 :name :t :position 1}
              :type :symbol
              :value "print"}]}])

(test (mtch "(print")
  [{:end 6
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :ptuple
    :value @[{:end 6
              :partial? :maybe
              :source {:column 2 :line 1 :name :t :position 1}
              :type :symbol
              :value "print"}]}])

(test (mtch "[]")
  [{:end 2
    :source {:column 1 :line 1 :name :t :position 0}
    :type :btuple
    :value @[]}])

(test (mtch "[[]]")
  [{:end 4
    :source {:column 1 :line 1 :name :t :position 0}
    :type :btuple
    :value @[{:end 3
              :source {:column 2 :line 1 :name :t :position 1}
              :type :btuple
              :value @[]}]}])

(test-error (mtch ")") "Unmatched closing parenthesis in \"t\" at line 1 column 1")
(test-error (mtch " \n\n   #]\n ]") "Unmatched closing square bracket in \"t\" at line 4 column 2")

# Strings

(test (mtch `"`)
  [{:end 1
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value ""}])

(test (mtch `""`)
  [{:end 2
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value ""}])

(test (mtch `"\n\\`)
  [{:end 5
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\n\\"}])

(test (mtch `"\n\\"`)
  [{:end 6
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\n\\"}])

(test (mtch `"\x`)
  [{:end 3
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value ""}])

(test (mtch `"\xf`)
  [{:end 4
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value ""}])

(test (mtch `"\xff"`)
  [{:end 6
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\xff"}])

(test (mtch `"\ufa12"`)
  [{:end 8
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\ufa12"}])

(test (mtch `"\u0333"`)
  [{:end 8
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\u0333"}])

(test (mtch `"\U10FFFF"`)
  [{:end 10
    :source {:column 1 :line 1 :name :t :position 0}
    :type :string
    :value "\U10FFFF"}])

(test (mtch `@"Hello, world!"`)
  [{:end 16
    :source {:column 2 :line 1 :name :t :position 1}
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
    :end 1
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :long-string
    :value ""}])
#"))

(test (mtch ```
``
```)
  [{:delim "``"
    :end 2
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :long-string
    :value ""}])

(test (mtch ```
``Hello!``
```)
  [{:delim "``"
    :end 10
    :source {:column 1 :line 1 :name :t :position 0}
    :type :long-string
    :value "Hello!"}])

(test (mtch ```
``Hello!\n``
```)
  [{:delim "``"
    :end 12
    :source {:column 1 :line 1 :name :t :position 0}
    :type :long-string
    :value "Hello!\\n"}])

(test (mtch ```
  ``Hello!\n``
```)
  [{:delim "``"
    :end 14
    :source {:column 3 :line 1 :name :t :position 2}
    :type :long-string
    :value "Hello!\\n"}])

(test (mtch ```
  ``
  A line.
  ``
```)
  [{:delim "``"
    :end 19
    :source {:column 3 :line 1 :name :t :position 2}
    :type :long-string
    :value "\n  A line.\n  "}])

# Structs

(test (mtch "{}")
  [{:end 2
    :source {:column 1 :line 1 :name :t :position 0}
    :type :struct
    :value @[]}])

(test (mtch "{:hello")
  [{:end 7
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :struct
    :value @[{:end 7
              :partial? :maybe
              :source {:column 2 :line 1 :name :t :position 1}
              :type :keyword
              :value "hello"}]}])

(test (mtch "{:hello :world")
  [{:end 14
    :partial? true
    :source {:column 1 :line 1 :name :t :position 0}
    :type :struct
    :value @[{:end 7
              :source {:column 2 :line 1 :name :t :position 1}
              :type :keyword
              :value "hello"}
             {:end 14
              :partial? :maybe
              :source {:column 9 :line 1 :name :t :position 8}
              :type :keyword
              :value "world"}]}])

(test (mtch "{:hello :world}")
  [{:end 15
    :source {:column 1 :line 1 :name :t :position 0}
    :type :struct
    :value @[{:end 7
              :source {:column 2 :line 1 :name :t :position 1}
              :type :keyword
              :value "hello"}
             {:end 14
              :source {:column 9 :line 1 :name :t :position 8}
              :type :keyword
              :value "world"}]}])

(test-error (mtch "}") "Unmatched closing curly bracket in \"t\" at line 1 column 1")
