(import stx)

(defn as [obj]
  (match (type obj)
    :stx (table/to-struct (merge (stx/as-struct obj) {:value (as (stx/value obj))}))
    :tuple (keep-syntax! obj (map as obj))
    :array (map as obj)
    :table (do (def result @{})
               (eachk key obj (set (result (as key)) (as (obj key))))
               result)
    :struct
     (do (def result @[])
         (eachk key obj (array/push result (as key) (as (obj key))))
         (struct ;result))
     obj))
