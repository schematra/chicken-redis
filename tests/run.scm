(import (chicken string))
(import r7rs
        test
        (chicken base)
        (chicken port)
        (chicken io)
        (srfi 34)	;; Exception Handling
        (srfi 35)	;; Exception Types
        (srfi 69)	;; Hash Tables
        (srfi 99)	;; Extended Records
        (srfi 113)	;; Sets and Bags
        (srfi 128)	;; Comparators
        (srfi 133)	;; Vectors
        (srfi 152)	;; Strings
        (srfi 158)	;; Generators and Accumulators
)

;; [[file:../redis.org::*API][API:3]]
(include-relative "../redis-impl.scm")
;; API:3 ends here



;; #+name: simple-string-test

;; [[file:../redis.org::simple-string-test][simple-string-test]]
(test-group "Simple strings"
    (test "+this is a simple string."
          "this is a simple string."
          (with-input-from-string "this is a simple string.\r\n" read-redis-simple-string)))
;; simple-string-test ends here

;; [[file:../redis.org::*Blob Strings][Blob Strings:2]]
(test-group "Blob strings"
  (test "$10\r\nhelloworld"
        "helloworld"
        (with-input-from-string "10\r\nhelloworld\r\n" read-redis-blob-string)))
;; Blob Strings:2 ends here

;; [[file:../redis.org::*Integers][Integers:2]]
(test-group "Integers"
  (test ":180" 180
        (with-input-from-string "180\r\n" read-redis-number)))
;; Integers:2 ends here

;; Bignums
;; Bignums are prefixed with ~(~.

;; #+begin_example
;; (3492890328409238509324850943850943825024385
;; #+end_example


;; [[file:../redis.org::*Bignums][Bignums:1]]
(test-group "Bignums"
  (test "(3492890328409238509324850943850943825024385" 3492890328409238509324850943850943825024385
        (with-input-from-string "3492890328409238509324850943850943825024385\r\n" read-redis-number)))
;; Bignums:1 ends here

;; [[file:../redis.org::*Booleans][Booleans:2]]
(test-group "Booleans"
  (test "#t" #t
        (with-input-from-string "t" read-redis-bool))
  (test "#f" #f
        (with-input-from-string "f" read-redis-bool)))
;; Booleans:2 ends here

;; [[file:../redis.org::*Null][Null:2]]
(test-group "Null"
  (test "_" '()
        (with-input-from-string "" read-redis-null)))
;; Null:2 ends here

;; [[file:../redis.org::*Arrays][Arrays:2]]
(test-group "Arrays"
  (test "*3:1:2:3" #(1 2 3)
        (with-input-from-string "3\r\n:1\r\n:2\r\n:3\r\n" read-redis-array)))
;; Arrays:2 ends here

;; [[file:../redis.org::*Maps][Maps:2]]
(test-group "Maps"
  (let ((ht (with-input-from-string "2\r\n+first\r\n:1\r\n+second\r\n:2\r\n" read-redis-map)))
    (test 1 (hash-table-ref ht "first"))
    (test 2 (hash-table-ref ht "second"))))
;; Maps:2 ends here

;; [[file:../redis.org::*Sets][Sets:2]]
(test-group "Sets"
  (test-assert "~4+orange+apple#t#f"
    (set=? (set (redis-set-comparator) "orange" "apple" #t #f)
           (with-input-from-string "4\r\n+orange\r\n+apple\r\n#t\r\n#f\r\n" read-redis-set))))
;; Sets:2 ends here

;; [[file:../redis.org::*About this egg][About this egg:2]]
(test-exit)
;; About this egg:2 ends here
