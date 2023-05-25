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

(defn- parser/readermac-type [readermac]
  (match readermac
    "'" :quote
     ";" :splice
     "~" :quasiquote
     "," :unquote
     "|" :short-fn
     `\'` :stx/quote
     # else
     (errorf "Internal stx error: Unknown reader macro %v" readermac)))

# :partial? can be true, :maybe, :number-error, or nil.
# true means that the text can be parsed as the beginning of a valid value, but there would be an error if this was EOF.
# :maybe means that the text can be parsed as a full value or as the beginning of a valid value. The value can be used as-is on EOF.
# :number-error means that it is something that might become a number if more characters are added, but otherwise this is error.
# nil means that the value is complete.
(def parser/pattern
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
                  ,(fn [n l c i] {:name n :line l :column c :position i}))
     :ws (set " \t\r\f\n\0\v")
     :comment (* "#" (thru (+ "\n" -1)))
     :space (any (+ :ws :comment))
     :readermac (cmt (* :source '(+ (set `';~,|`) `\'`)
                        :space
                        (+ :reader-value
                           (* -1 (constant {:partial? true}))
                           :root-err)
                        (position))
                     ,(fn [s x val e]
                        {:type (parser/readermac-type x) :value val :source s
                         :partial? (val :partial?) :end e}))
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
     :symbol (cmt (* :source ':token :maybe-partial (position))
                  ,(fn [s x p e]
                     (def invalid-symbol?
                       (and (first x) (>= (first x) (chr "0")) (<= (first x) (chr "9"))))
                     (when (and (not p) invalid-symbol?)
                       (errorf `Invalid number in "%s" at line %d column %d` (s :name) (s :line) (s :column)))
                     (def type (match x
                                 "true" :true "false" :false "nil" :nil
                                  :symbol))
                     {:type type :value x :source s :partial? (if invalid-symbol? :number-error p) :end e}))
     :keyword (cmt (* :source ":" '(any :symchars) :maybe-partial (position))
                   ,(fn [s x p e] {:type :keyword :value x :source s :partial? p :end e}))
     :bytes (* :source `"`
               (% (any (+ :escape '(if-not "\"" 1))))
               (+ (* `"` (constant nil))
                  (* -1 (constant true))))
     :string (cmt (* :bytes (position))
                ,(fn [s x p e] {:type :string :value x :source s :partial? p :end e}))
     :buffer (cmt (* "@" :bytes (position))
                  ,(fn [s x p e] {:type :buffer :value x :source s :partial? p :end e}))
     :long-bytes {:delim (some "`")
                  :open (capture :delim :n)
                  :close (cmt (* (not (> -1 "`")) (-> :n) ':delim) ,=)
                  :main (* :open '(any (if-not :close 1))
                                  (+ (* (drop :close) (constant nil))
                                     (* -1 (constant true))))}
     :long-string (cmt (* :source :long-bytes (position))
                       ,(fn [s d x p e] {:type :long-string :value x :delim d :source s :partial? p :end e}))
     :long-buffer (cmt (* :source "@" :long-bytes (position))
                       ,(fn [s d x p e] {:type :long-buffer :value x :delim d :source s :partial? p :end e}))
     :number (cmt (* :source (cmt (<- :token) ,scan-number) :maybe-partial (position))
                  ,(fn [s x p e] {:type :number :value x :source s :partial? p :end e}))
     :backslash (cmt (* :source "\\"
                        (+ (* -1 (constant {:partial? true}))
                           (* (look 0 "(") :ptuple)
                           (* (look 0 "`") :long-string))
                        (position))
                     ,(fn [s x e]
                        (def type (match (x :type)
                                    :ptuple :stx-ptuple :long-string :stx-long-string nil :stx-partial
                                     (errorf "Internal stx error caused in \"%s\" at line %d column %d"
                                             (s :name) (s :line) (s :column))))
                        {:type type :value x :source s :partial? (x :partial?) :end e}))
     :raw-value (+ :number :keyword
                   :string :buffer :long-string :long-buffer
                   :parray :barray :ptuple :btuple :struct :table :symbol :backslash)
     :reader-value (+ :readermac :raw-value)
     :value (* :space :reader-value :space)
     :root (any :value)
     :root2 (any (* :value :value))
     :ptuple-inner (* "(" (group :root)
                      (+ (* ")" (constant nil))
                         (* :space -1 (constant true))
                         (error (* (constant "Unmatched parenthesis" :message) :delim-err)))
                      (position))
     :ptuple (cmt (* :source :ptuple-inner)
                  ,(fn [s x p e] {:type :ptuple :value x :source s :partial? p :end e}))
     :btuple-inner (* "[" (group :root)
                      (+ (* "]" (constant nil))
                         (* :space -1 (constant true))
                         (error (* (constant "Unmatched square bracket" :message) :delim-err)))
                      (position))
     :btuple (cmt (* :source :btuple-inner)
                  ,(fn [s x p e] {:type :btuple :value x :source s :partial? p :end e}))
     :struct-inner (* "{" (group :root2)
                      (+ (* "}" (constant nil))
                         (* :space (+ (* (drop :root) -1) -1) (constant true))
                         (* :space (drop :root) "}"
                            (error (* (constant "Odd number of values in struct or table" :message) :delim-err)))
                         (error (* (constant "Unmatched curly bracket" :message) :delim-err)))
                      (position))
     :struct (cmt (* :source :struct-inner)
                  ,(fn [s x p e] {:type :struct :value x :source s :partial? p :end e}))
     :parray (cmt (* :source "@" :ptuple-inner)
                  ,(fn [s x p e] {:type :parray :source s :value x :partial? p :end e}))
     :barray (cmt (* :source "@" :btuple-inner)
                  ,(fn [s x p e] {:type :barray :source s :value x :partial? p :end e}))
     :table (cmt (* :source "@" :struct-inner)
                 ,(fn [s x p e] {:type :table :source s :value x :partial? p :end e}))
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
                  (error (* (constant "Invalid value" :message) :err)))
     :main (* :root (* :space (+ -1 :root-err)))}))

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

  (defn wrap-reader [name value]
    (wrap-tuple tuple [name value]))

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
    :quote (wrap-reader 'quote (pat :value))
    :splice (wrap-reader 'splice (pat :value))
    :quasiquote (wrap-reader 'quasiquote (pat :value))
    :unquote (wrap-reader 'unquote (pat :value))
    :short-fn (wrap-reader 'short-fn (pat :value))
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
        (defn do-err [e]
          (set (parser :state) [:error e]))

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
    (do (set (parser :state) [:error {:type :peg :error err :fiber fiber}])
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

(defn parser/error [parser]
  (when (= (parser/state-key parser) :error)
    (def err ((parser :state) 1))
    (match (err :type)
      :peg (err :error)
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

(defmacro sourcemap/run
  ```Execute a string in a singleton tuple as code. The tuple's sourcemap is
  used to find the line number of the string contents, which is assumed to be
  one line below the start of the tuple at column 1. The file name defaults to current-file.
  ```
  [code &opt opts]
  ~(do
     (def code ,code)
     (def sm (,tuple/sourcemap code))
     (var x false)
     (,parser/run
       (,merge
         {:parser (,parser/new (,inc (,first sm)) 1)
          :chunks (fn [buf p]
                    (if (,not x)
                      (do (set x true) (,buffer/push-string buf (,first code)))
                      nil))}
         (or ,opts {})))))

(def stx-env (curenv))

(defn init
  `Initialize the stx syntax loader, allowing ".stx.janet" files to be imported.`
  []
  (def key :stx-syntax)
  (unless (get module/loaders key)
    (defn loader [path args]
      (with [file (file/open path :rn)]
            (parser/run
             {:source path
              :parser (parser/new)
              :env (table/setproto (merge-module @{} stx-env "stx/") root-env)
              :chunks (fn [buf p] (file/read file :all buf))})))
    (put module/loaders key loader)
    (array/push module/paths [":all:.stx.janet" key])))

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
