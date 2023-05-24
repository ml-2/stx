(declare-project
 :name "stx"
 :description "Abstractions for Janet"
 :dev-dependencies [
    {:url "https://github.com/ianthehenry/judge.git"
     :tag "v2.5.0"}])

(declare-native
  :name "stx/native"
  :source ["src/stx.c"])

(declare-source
 :source ["src/init.janet"]
 :prefix "stx")

(task "test" [] (shell "jpm -l exec jpm_tree/bin/judge test/"))
