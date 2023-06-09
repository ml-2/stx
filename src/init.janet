# TODO: Add support for \name() syntax for reader macros. \() is for lisp-like delimed syntax, \[] is for syntax which is not lisp-like. It follows a permissive delim system. This is important for metamath, because \``` ``` or '(```\n``` is not ergonomic.

(import "stx/native" :prefix "" :export true)

(defn stx? [x] (= (type x) :stx))

(defn dec-depth [obj &opt new-value]
  (if (= (depth obj) 0)
    (or new-value (value obj))
    (new (name obj) (line obj) (column obj) (or new-value (value obj))
         (dec (depth obj)))))

(defn unwrap [obj]
  (if (stx? obj)
    (dec-depth obj)
    obj))

(defn unwrap*
  `Unwraps object recursively. Recurs on stx, tuple, array, table, and struct
  values. Does not take prototypes into consideration.`
  [obj]
  (match (type obj)
    :stx (dec-depth obj (unwrap* (value obj)))
    :tuple (keep-syntax! obj (map unwrap* obj))
    :array (map unwrap* obj)
    :table (do (def result @{})
               (eachk key obj (set (result (unwrap* key)) (unwrap* (obj key))))
               result)
    :struct
     (do (def result @[])
         (eachk key obj (array/push result (unwrap* key) (unwrap* (obj key))))
         (struct ;result))
     obj))

(defn sourcemap [syntax]
  [(line syntax) (column syntax)])

(defn keep [syntax new-val]
  (cond (stx? new-val)
        new-val
        (stx? syntax)
        (new (name syntax) (line syntax) (column syntax) (unwrap new-val))
        new-val))

(defn as-struct [syntax]
  {:name (name syntax) :line (line syntax) :column (column syntax) :value (value syntax)
   :depth (depth syntax)})

(defn- parser/unicode-hex [source hex]
  (def num (scan-number hex 16))
  (when (> num 0x10FFFF)
    (errorf "Invalid unicode codepoint in \"%s\" at line %d column %d"
            (source :name) (source :line) (source :column)))
  (cond
    (< num 0x80)
    (string/from-bytes num)
    (< num 0x800)
    (string/from-bytes (bor (band (brshift num 06) 0x1f) 0xc0)
                       (bor (band (brshift num 00) 0x3f) 0x80))
    (< num 0x10_000)
    (string/from-bytes (bor (band (brshift num 12) 0x0f) 0xe0)
                       (bor (band (brshift num 06) 0x3f) 0x80)
                       (bor (band (brshift num 00) 0x3f) 0x80))

    (string/from-bytes (bor (band (brshift num 18) 0x07) 0xf0)
                       (bor (band (brshift num 12) 0x3f) 0x80)
                       (bor (band (brshift num 06) 0x3f) 0x80)
                       (bor (band (brshift num 00) 0x3f) 0x80))))

(def parser/pattern
  (do
    (defn simple [typ]
      (fn [s x p e] {:type typ :value x :source s :partial? p :end e}))

    (defn delim [typ]
      (fn [s d x p e] {:type typ :delim d :value x :source s :partial? p :end e}))

    (defn sym [s x p e]
      (def invalid-symbol?
        (and (first x) (>= (first x) (chr "0")) (<= (first x) (chr "9"))))
      (when (and (not p) invalid-symbol?)
        (errorf `Invalid number in "%s" at line %d column %d` (s :name) (s :line) (s :column)))
      (def type (match x
                  "true" :true "false" :false "nil" :nil
                   :symbol))
      {:type type :value x :source s
       :partial? (if invalid-symbol? :number-error p)
       :end e})

    (defn structlike [typ]
      (fn [s x o p e]
        (when o (array/push x o))
        {:type typ :value x :source s :partial? p :end e}))

    (defn backslash [s x e]
      (def type (match (x :type)
                  :ptuple :stx-ptuple :long-string :stx-long-string nil :stx-partial
                   (errorf "Internal stx error caused in \"%s\" at line %d column %d"
                           (s :name) (s :line) (s :column))))
      {:type type :value x :source s :partial? (x :partial?) :end e})

    (defn readermac [s x val e]
      (when (= x `\'`)
        (break {:type :stx/quote :value val :source s
                :partial? (val :partial?) :end e}))
      (def sym (match x
                 "'" "quote"
                 ";" "splice"
                 "~" "quasiquote"
                 "," "unquote"
                 "|" "short-fn"
                 # else
                 (errorf "Internal stx error: Unknown reader macro %v" readermac)))
      {:type (keyword sym)
       :value {:type :ptuple :value @[((simple :symbol) s sym (val :partial?) e) val]
               :source s :partial? (val :partial?) :end e}
       :source s :partial? (val :partial?) :end e})

    # :partial? can be true, :maybe, :number-error, or nil.
    # true means that the text can be parsed as the beginning of a valid value,
    #   but there would be an error if this was EOF.
    # :maybe means that the text can be parsed as a full value or as the
    #   beginning of a valid value. The value can be used as-is on EOF.
    # :number-error means that it is something that might become a number if
    #   more characters are added, but otherwise this is error.
    # nil means that the value is complete.
    (peg/compile
     ~{# :source must always be at the very beginning of every object, because it
       # is used to determine from where to try again when a value is partial.
       :source (cmt (* (argument 0 :name)
                       (cmt (* (argument 1) (line))
                            ,(fn [l0 l1] (+ (dec (or l0 1)) l1))
                            :line)
                       (cmt (* (argument 1) (line) (argument 2) (column))
                            ,(fn [l0 l1 c0 c1] (if (= l0 l1) (+ (dec (or c0 1)) c1) c1))
                            :column)
                       (position :position))
                    ,(fn source [n l c i] {:name n :line l :column c :position i}))
       # Error helpers
       :err (cmt (* :space (backref :message) :source)
                 ,(fn [m {:name n :line l :column c}] (string/format `%s in "%s" at line %d column %d` m n l c)))
       :delim-err (cmt (* :space (backref :message) (backref :name) (backref :line) (backref :column))
                       ,(fn [m n l c] (string/format "%s in \"%s\" at line %d column %d" m n l c)))
       :root-err (+ (* (look 0 ")")
                       (error (* (constant "Unmatched closing parenthesis" :message) :err)))
                    (* (look 0 "]")
                       (error (* (constant "Unmatched closing square bracket" :message) :err)))
                    (* (look 0 "}")
                       (error (* (constant "Unmatched closing curly bracket" :message) :err)))
                    (error (* (constant "Invalid syntax" :message) :err)))
       :ws (set " \t\r\f\n\0\v")
       :comment (* "#" (thru (+ "\n" -1)))
       :space (any (+ :ws :comment))
       :symchars (+ (range "09" "AZ" "az" "\x80\xFF") (set "!$%&*+-./:<?=>@^_"))
       :token (some :symchars)
       :hex (range "09" "af" "AF")
       :escape (* "\\" (+ (* "n" (constant "\n"))
                          (* "t" (constant "\t"))
                          (* "r" (constant "\r"))
                          (* "z" (constant "\z"))
                          (* "f" (constant "\f"))
                          (* "e" (constant "\e"))
                          (* "v" (constant "\v"))
                          (* "0" (constant "\0"))
                          (* "\\" (constant "\\"))
                          (* `"` (constant `"`))
                          (* "x" (+ (/ '[2 :hex] ,|(string/from-bytes (scan-number $ 16)))
                                    (* (? :hex) -1)))
                          (* "u" (+ (cmt (* :source '[4 :hex]) ,parser/unicode-hex)
                                    (* (at-most 3 :hex) -1)))
                          (* "U" (+ (cmt (* :source '[6 :hex]) ,parser/unicode-hex)
                                    (* (at-most 5 :hex) -1)))
                          -1
                          (error (* (constant "Invalid escape" :message) :err))))
       :maybe-partial (+ (* -1 (constant :maybe)) (constant nil))
       :symbol (cmt (* :source
                       ':token
                       :maybe-partial (position))
                    ,sym)
       :keyword (cmt (* :source
                        ":" '(any :symchars)
                        :maybe-partial (position))
                     ,(simple :keyword))
       :bytes (* :source `"`
                 (% (any (+ :escape '(if-not "\"" 1))))
                 (+ (* `"` (constant nil))
                    (* -1 (constant true))))
       :string (cmt (* :bytes (position)) ,(simple :string))
       :buffer (cmt (* "@" :bytes (position)) ,(simple :buffer))
       :long-bytes {:delim (some "`")
                    :open (capture :delim :n)
                    :close (cmt (* (not (> -1 "`")) (-> :n) ':delim) ,=)
                    :main (* :open '(any (if-not :close 1))
                             (+ (* (drop :close) (constant nil))
                                (* -1 (constant true))))}
       :long-string (cmt (* :source :long-bytes (position)) ,(delim :long-string))
       :long-buffer (cmt (* :source "@" :long-bytes (position)) ,(delim :long-buffer))
       :number (cmt (* :source
                       (cmt (<- :token) ,scan-number)
                       :maybe-partial (position))
                    ,(simple :number))
       :backslash (cmt (* :source "\\"
                          (+ (* -1 (constant {:partial? true}))
                             (* (look 0 "(") :ptuple)
                             (* (look 0 "`") :long-string))
                          (position))
                       ,backslash)
       :ptuple-inner (* "(" (group :root)
                        (+ (* ")" (constant nil))
                           (* :space -1 (constant true))
                           (error (* (constant "Unmatched parenthesis" :message) :delim-err)))
                        (position))
       :ptuple (cmt (* :source :ptuple-inner) ,(simple :ptuple))
       :btuple-inner (* "[" (group :root)
                        (+ (* "]" (constant nil))
                           (* :space -1 (constant true))
                           (error (* (constant "Unmatched square bracket" :message) :delim-err)))
                        (position))
       :btuple (cmt (* :source :btuple-inner) ,(simple :btuple))
       :struct-inner (* "{" (group :root2)
                        (+ (* (constant nil) "}" (constant nil))
                           (* :space (+ (* :value -1) (* (constant nil) -1)) (constant true))
                           (* :space (drop :value) "}"
                              (error (* (constant "Odd number of values in struct or table" :message) :delim-err)))
                           (error (* (constant "Unmatched curly bracket" :message) :delim-err)))
                        (position))
       :struct (cmt (* :source :struct-inner) ,(structlike :struct))
       :parray (cmt (* :source "@" :ptuple-inner) ,(simple :parray))
       :barray (cmt (* :source "@" :btuple-inner) ,(simple :barray))
       :table (cmt (* :source "@" :struct-inner) ,(structlike :table))
       :readermac (cmt (* :source '(+ (set `';~,|`) `\'`)
                          :space
                          (+ :raw-value
                             (* -1 (constant {:partial? true}))
                             :root-err)
                          (position))
                       ,readermac)
       :raw-value (+ :readermac :number :keyword
                     :string :buffer :long-string :long-buffer
                     :parray :barray :ptuple :btuple :struct :table :symbol :backslash)
       :value (* :space :raw-value :space)
       :root (any :value)
       :root2 (any (* :value :value))
       :main (* :root (* :space (+ -1 :root-err)))})))

(defn parser/source-to-stx [source value dpt]
  (if (= (type value) :stx)
    (errorf "Internal stx error: Tried to wrap syntax in syntax in %s at line %d column %d"
            (source :name) (source :line) (source :column))
    (new (source :name) (source :line) (source :column) value dpt)))

(defn parser/pattern-to-object [pat &opt dpt]
  (defn wrap [val &opt source]
    (if-not dpt
      val
      (parser/source-to-stx (or source (pat :source)) val dpt)))

  (defn wrap-stringlike [value offset &opt source]
    (def source (or source (pat :source)))
    (wrap value {:name (source :name) :line (source :line) :column (+ (source :column) offset)}))

  (defn wrap-long [mut? &opt $pat]
    (def pat (or $pat pat))
    (def src (pat :source))
    (def buf (buffer/new-filled (+ (dec (src :column))) (chr " ")))
    (when mut?
      (buffer/push-byte buf (chr "@")))
    (buffer/push-string buf (pat :delim))
    (buffer/push-string buf (pat :value))
    (buffer/push-string buf (pat :delim))
    (if (= (first (pat :value)) (chr "\n"))
      (wrap-stringlike (parse buf) 0 {:name (src :name) :line (inc (src :line))
                                      :column 1 :position (inc (src :position))})
      (wrap-stringlike (parse buf) (+ (length (pat :delim)) (if mut? 1 0)) src)))

  (defn wrap-map [fun values]
    (wrap (fun ;(map |(parser/pattern-to-object $ dpt) values))))

  (defn wrap-tuple [fun values]
    (def result (wrap-map fun values))
    (wrap (tuple/setmap (if (stx? result) (value result) result)
                        ((pat :source) :line) ((pat :source) :column))))

  (defn wrap-stx-ptuple []
    (def values ((pat :value) :value))
    (def result [(parser/pattern-to-object (first values) dpt)
                       ;(map |(parser/pattern-to-object $ (if dpt (inc dpt) 0)) (array/slice values 1))])
    (tuple/setmap result ((pat :source) :line) ((pat :source) :column))
    (wrap result))

  (match (pat :type)
    :symbol (wrap (symbol (pat :value)))
    :true (wrap true)
    :false (wrap false)
    :nil (wrap nil)
    :keyword (wrap (keyword (pat :value)))
    :string (wrap-stringlike (pat :value) 1)
    :buffer (wrap-stringlike (buffer (pat :value)) 2)
    :long-string (wrap-long false)
    :long-buffer (wrap-long true)
    :number (wrap (pat :value))
    :ptuple (wrap-tuple tuple (pat :value))
    :btuple (wrap-tuple tuple/brackets (pat :value))
    :struct (wrap-map struct (pat :value))
    :parray (wrap-map array (pat :value))
    :barray (wrap-map array (pat :value))
    :table (wrap-map table (pat :value))
    :quote (parser/pattern-to-object (pat :value) dpt)
    :splice (parser/pattern-to-object (pat :value) dpt)
    :quasiquote (parser/pattern-to-object (pat :value) dpt)
    :unquote (parser/pattern-to-object (pat :value) dpt)
    :short-fn (parser/pattern-to-object (pat :value) dpt)
    :stx/quote (parser/pattern-to-object (pat :value) (if dpt (inc dpt) 0))
    :stx-ptuple (wrap-stx-ptuple)
    :stx-long-string (wrap-stringlike ((pat :value) :value) (inc (length ((pat :value) :delim))))
     # else
     (errorf "Internal stx error: Unknown pattern type %v" (pat :type))))

(def- queue/push array/push)
(def- queue/empty? empty?)
(defn queue/dequeue [queue]
  (def result (first queue))
  (array/remove queue 0 1)
  result)

(defn parser/state-key [parser]
  ((parser :state) 0))

(defn parser/consume [parser bytes &opt index]
  (defn do-err [e] (set (parser :state) [:error e]))
  (def num-read (- (length bytes) (or index 0)))
  (when (= (parser/state-key parser) :error)
    (break num-read))
  (buffer/push-string (parser :buffer) (if index (string/slice bytes index) bytes))
  (match
      (try
        [:ok (peg/match parser/pattern (parser :buffer) (parser :position)
                        (or (dyn *current-file*) :<anonymous>)
                        (parser :start-line)
                        (parser :start-column))]
        ([err fiber] [:error err fiber]))
    [:ok matches]
    (do
      (each elem matches

        (def eof? (= (parser/state-key parser) :eof))
        (defn push []
          (queue/push (parser :queue) elem)
          (set (parser :position) (elem :end)))

        (match (elem :partial?)
          nil (push)
          :maybe (if eof?
                   (push)
                   (set (parser :position) ((elem :source) :position)))
          :number-error (when eof? (do-err {:type :number :value elem}))
          true (when eof? (do-err {:type :partial :value elem}))
          (errorf "Internal stx error: Unknown partial type %v" (elem :partial?))))
      num-read)
    [:error err fiber]
    (do (do-err {:type :peg :error err :fiber fiber})
        num-read)))

(defn parser/produce [parser &opt wrap?]
  (when (not= (parser/state-key parser) :error)
    (def obj (queue/dequeue (parser :queue)))
    (unless obj
      (break nil))
    (def result (parser/pattern-to-object obj))
    (if-not wrap?
      result
      (tuple/setmap [result] ((obj :source) :line) ((obj :source) :column)))))

(defn parser/status [parser]
  (def at-end? (= (parser :position) (length (parser :buffer))))
  (def state (parser/state-key parser))
  (cond
    (= state :error)
    :error
    at-end?
    :root
    (and at-end? (= state :eof))
    :dead
    # else
    :pending))

(defn parser/has-more [parser]
  (and (not= (parser/state-key parser) :error)
       (not (queue/empty? (parser :queue)))))

(defn parser/eof [parser]
  (when (not= (parser/state-key parser) :error)
    (set (parser :state) [:eof nil])
    (:consume parser "")))

(def- lc-pattern
  (peg/compile ~(* (cmt (* (argument 0) (line))
                        ,(fn [l0 l1] (+ (dec (or l0 1)) l1)))
                   (cmt (* (argument 0) (line) (argument 1) (column))
                        ,(fn [l0 l1 c0 c1] (if (= l0 l1) (+ (dec (or c0 1)) c1) c1))))))

(defn parser/where [parser]
  (tuple ;(peg/match
           lc-pattern
           (parser :buffer) (parser :position) (parser :start-line) (parser :start-column))))


(defn- parser/partial-error [pat]
  (defn internal-error []
    (string/format "Internal stx error: Impossible type and partial combination [%v %v]"
                   (pat :type) (pat :partial?)))
  (defn message [msg src & args]
    (string/format (string msg " in file \"%s\" at line %d column %d")
                   ;args
                   (src :name) (src :line) (src :column)))
  (defn on-container []
    (def inner-val (last (pat :value)))
    (if (and inner-val (inner-val :type) (get {true true :number-error true} (inner-val :partial?)))
      (parser/partial-error inner-val)
      (message "Unterminated %s value" (pat :source) (pat :type))))
  (defn on-readermac []
    (def inner-val (((pat :value) :value) 1))
    (if (inner-val :type)
      (parser/partial-error inner-val)
      (message "%s without a value" (pat :source) (pat :type))))
  (defn on-stx-quote []
    (def inner-val (pat :value))
    (if (and inner-val (inner-val :type))
      (parser/partial-error inner-val)
      (message "Unterminated %s value" (pat :source) (pat :type))))
  (match (pat :type)
    :symbol (do
              # Can only error if this is :number-error
              (assert (= (pat :partial?) :number-error) (internal-error))
              (message "Invalid number %s" (pat :source) (pat :value)))
    # :true # Impossible state
    # :false # Impossible state
    # :nil # Impossible state
    # :keyword # Impossible state
    :string (message "Unterminated string literal" (pat :source))
    :buffer (message "Unterminated buffer literal" (pat :source))
    :long-string (message "Unterminated long string literal" (pat :source))
    :long-buffer (message "Unterminated long buffer literal" (pat :source))
    # :number # Impossible state
    :ptuple (on-container)
    :btuple (on-container)
    :struct (on-container)
    :parray (on-container)
    :barray (on-container)
    :table (on-container)
    :quote (on-readermac)
    :splice (on-readermac)
    :quasiquote (on-readermac)
    :unquote (on-readermac)
    :short-fn (on-readermac)
    :stx/quote (on-stx-quote)
    :stx-ptuple (parser/partial-error (pat :value))
    :stx-long-string (message "Unterminated long string literal" (pat :source))
    # else
    (error (internal-error))))

(defn parser/error [parser]
  (when (= (parser/state-key parser) :error)
    (def err ((parser :state) 1))
    (match (err :type)
      :peg (err :error)
      :partial (parser/partial-error (err :value))
      :number
       (do (def src ((err :value) :source))
           (string/format "Invalid number %s in \"%s\" at line %d column %d"
                          ((err :value) :value)
                          (src :name) (src :line) (src :column)))
      (string/format "Internal stx error: Unknown error type %v" (err :type)))))

(def parser/prototype
  @{:consume parser/consume
    :produce parser/produce
    :status parser/status
    :has-more parser/has-more
    :where parser/where
    :error parser/error
    :eof parser/eof})

(defn parser/new [&opt line column]
  (def state @{:buffer @"" :queue @[] :state [:ok nil] :position 0 :start-line line :start-column column})
  (table/setproto state parser/prototype))

(defn parser/run [opts]
  (run-context
   (merge
    {:parser (parser/new)
     :on-parse-error (fn [parser where] (error (parser/error parser)))
     :on-compile-error
       (fn [msg macrof where &opt line col]
         (def buf @"")
         (with-dyns [*err* buf
                     *err-color* false]
           (bad-compile msg macrof where line col))
         (if macrof
           (propagate buf macrof)
           (error buf)))
     :fiber-flags :y
     :on-status (fn [f res]
                  (unless (= (fiber/status f) :dead)
                    (propagate res f)))}
    opts)))

(defn sourcemap/run
  ```Execute a string in a singleton tuple as code. The tuple's sourcemap is
  used to find the line number of the string contents, which is assumed to be
  one line below the start of the tuple at column 1. The file name defaults to current-file.
  ```
  [code &opt opts]
  (def sm (tuple/sourcemap code))
  (var x false)
  (parser/run
   (merge
    {:parser (parser/new (inc (first sm)) 1)
     :chunks (fn [buf p]
               (if (not x)
                 (do (set x true) (buffer/push-string buf (first code)))
                 nil))}
    (or opts {}))))

(def stx-env (curenv))

(defn module/loader [path args]
  (with-dyns [*current-file* path]
    (with [file (file/open path :rn)]
          (parser/run
           {:source path
            :parser (parser/new)
            :env (table/setproto (merge-module @{} stx-env "stx/") root-env)
            :chunks (fn [buf p] (file/read file :all buf))}))))

(defn init
  `Initialize the stx syntax loader, allowing ".janet.stx" files to be imported.`
  []
  (def key :stx-syntax)
  (unless (get module/loaders key)
    (put module/loaders key module/loader)
    (module/add-paths ".janet.stx" key)))

# Shadowing

(defn or
  `Returns a copy of the first argument which is a syntax object, with its
  contained value set to nil. Returns nil if no syntax objects were given.`
  [& syntax]
  (var result nil)
  (each elem syntax
    (when (stx? elem)
      (set result (new (name elem) (line elem) (column elem) nil))
      (break)))
  result)
