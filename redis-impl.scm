;; [[file:redis.org::*API][API:2]]
(import r7rs
        (chicken base)
        (chicken port)
        (chicken string)
        (chicken io)
        (chicken tcp)
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
;; API:2 ends here

;; Exceptions
;; This library defines an SRFI-35 exception type ~&redis-error~ that gets raised when Redis returns an error. The exception type has a single field called ~redis-error-message~ containing the error message returned by Redis.

;; [[file:redis.org::*Exceptions][Exceptions:1]]
(define-condition-type &redis-error &error
  redis-error?
  (redis-error-message redis-error-message))
;; Exceptions:1 ends here



;; Connects to a (hopefully) Redis server at =host:port=, using the given protocol version. Defaults, like Redis itself, to version 1.


;; [[file:redis.org::*Connection Management][Connection Management:2]]
(define-record-type redis-connection #t #t input output)
(define (redis-connect host port #!optional (protocol-version 1))
  (let-values (((i o) (tcp-connect host port)))
    (values (make-redis-connection i o)
            (and (write-line (string-append "HELLO " (->string protocol-version)) o)
                (redis-read-reply i)))))
;; Connection Management:2 ends here



;; Disconnects from =rconn= which must be a =redis-connection=.

;; [[file:redis.org::*Connection Management][Connection Management:4]]
(define (redis-disconnect rconn)
  (tcp-abandon-port (redis-connection-input rconn))
  (tcp-abandon-port (redis-connection-output rconn)))
;; Connection Management:4 ends here



;; Uses connection =rconn= to run =command= with =args=. The args will be appended to the command, space-separated. Returns the parsed reply.

;; [[file:redis.org::*Running Commands][Running Commands:2]]
(define (redis-run rconn command . args)
  (let ((in (redis-connection-input rconn))
        (out (redis-connection-output rconn))
        (comm (string-join (cons command args))))
    (write-line comm out)
    (redis-read-reply in)))
;; Running Commands:2 ends here



;; Calls =proc= with the output port of the =rconn= as current output port, optionally with =args=. Returns the parsed reply.

;; [[file:redis.org::*Running Commands][Running Commands:4]]
(define (redis-run-proc rconn proc . args)
  (let ((in (redis-connection-input rconn))
        (out (redis-connection-output rconn)))
    (with-output-to-port out
      (cut apply proc args))
    (redis-read-reply in)))
;; Running Commands:4 ends here

;; Supported Data Types

;; This Redis client supports all data types up to and including as specified in [[https://github.com/antirez/RESP3/blob/master/spec.md][RESP3]].

;; #+name: redis-read-reply

;; [[file:redis.org::redis-read-reply][redis-read-reply]]
(define (redis-read-reply #!optional port)
  (let* ((port (or port (current-input-port)))
         (sigil (read-char port)))
    (case sigil
      ((#\+) (read-redis-simple-string port))
      ((#\-) (raise (make-condition &redis-error 'redis-error-message (read-redis-simple-string port))))
      ((#\$) (read-redis-blob-string port))
      ((#\!) (raise (make-condition &redis-error 'redis-error-message (read-redis-blob-string port))))
      ((#\=) (read-redis-blob-string port))
      ((#\:) (read-redis-number port))
      ((#\,) (read-redis-number port))
      ((#\() (read-redis-number port))
      ((#\#) (read-redis-bool port))
      ((#\_) (read-redis-null port))
      ((#\*) (read-redis-array port))
      ((#\>) (read-redis-array port)) ;; RESP3 push array
      ((#\%) (read-redis-map port))
      ((#\~) (read-redis-set port))
      ((#\|) (read-redis-with-attributes port)))))
;; redis-read-reply ends here

;; Simple Strings
;; Simple strings start with ~+~ and are single-line.

;; #+name: read-redis-simple-string-example
;; #+begin_example
;; +this is a simple string.
;; #+end_example

;; #+name: read-redis-simple-string

;; [[file:redis.org::read-redis-simple-string][read-redis-simple-string]]
(define (read-redis-simple-string #!optional port)
  (let ((port (or port (current-input-port))))
    (read-line port)))
;; read-redis-simple-string ends here

;; Blob Strings
;; Blob strings are longer, potentially multi-line strings. Their sigil is ~$~, followed by an integer designating the string length.

;; #+begin_example
;; $7
;; chicken
;; #+end_example

;; #+name: read-redis-blob-string

;; [[file:redis.org::read-redis-blob-string][read-redis-blob-string]]
(define (read-redis-blob-string #!optional port)
  (let* ((port (or port (current-input-port)))
         (charcount (string->number (read-line port)))
         (str (list->string
               (generator-map->list
                (lambda (i) (read-char port))
                (make-range-generator 0 charcount)))))
    (read-line port)
    str))
;; read-redis-blob-string ends here

;; Integers
;; Integers are sent to the client prefixed with ~:~.

;; #+begin_example
;; :180
;; #+end_example

;; #+name: read-redis-number

;; [[file:redis.org::read-redis-number][read-redis-number]]
(define (read-redis-number #!optional port)
  (let* ((port (or port (current-input-port)))
         (elem (read-line port)))
    (if (string=? elem "inf")
        (string->number "+inf")
        (string->number elem))))
;; read-redis-number ends here

;; Booleans
;; True and false values are represented as ~#t~ and ~#f~, just like in Scheme.

;; #+name: read-redis-bool

;; [[file:redis.org::read-redis-bool][read-redis-bool]]
(define (read-redis-bool #!optional port)
  (let ((port (or port (current-input-port))))
    (string=? (read-line port) "t")))
;; read-redis-bool ends here

;; Null
;; The null type is encoded simply as ~_~, and results in ~'()~.

;; #+name: read-redis-null

;; [[file:redis.org::read-redis-null][read-redis-null]]
(define (read-redis-null #!optional port)
  (let ((port (or port (current-input-port))))
    (read-line port) '()))
;; read-redis-null ends here

;; Arrays
;; Arrays are marked with ~*~ followed by the number of entries, and get returned as srfi-133 vectors.

;; #+begin_example
;; *3
;; :1
;; :2
;; :3
;; #+end_example

;; #+name: read-redis-array

;; [[file:redis.org::read-redis-array][read-redis-array]]
(define (read-redis-array #!optional port)
  (let* ((port (or port (current-input-port)))
         (elems (max 0 (string->number (read-line port))))
         (vec (make-vector elems '())))
    (generator-for-each
     (lambda (i)
       (vector-set! vec i (redis-read-reply port)))
     (make-range-generator 0 elems))
    vec))
;; read-redis-array ends here

;; Maps
;; Maps are represented exactly as arrays, but instead of using the ~*~ byte, the encoded value starts with a ~%~ byte. Moreover the number of following elements must be even. Maps represent a sequence of field-value items, basically what we could call a dictionary data structure, or in other terms, an hash. They get returned as srfi-69 hash tables.

;; #+begin_example
;; %2
;; +first
;; :1
;; +second
;; :2
;; #+end_example

;; #+name: read-redis-map

;; [[file:redis.org::read-redis-map][read-redis-map]]
(define (read-redis-map #!optional port)
  (let* ((port (or port (current-input-port)))
         (elems (string->number (read-line port)))
         (ht (make-hash-table)))
    (generator-for-each
     (lambda (i)
       (hash-table-set! ht (redis-read-reply port) (redis-read-reply port)))
     (make-range-generator 0 elems))
    ht))
;; read-redis-map ends here

;; Sets
;; Sets are exactly like the Array type, but the first byte is ~~~ instead of ~*~. They get returned as srfi-113 sets.
;; Additionally, there is a parameter defined, =redis-set-comparator=, that specifies the default comparator to be used for sets. It defaults to `(make-default-comparator)`.

;; #+begin_example
;; ~4
;; +orange
;; +apple
;; #t
;; #f
;; #+end_example

;; #+name: read-redis-set

;; [[file:redis.org::read-redis-set][read-redis-set]]
(define redis-set-comparator
  (make-parameter (make-default-comparator)
                  (lambda (newcomp)
                    (or (and (comparator? newcomp)
                             newcomp)
                        '()))))

(define (read-redis-set #!optional port)
  (let* ((port (or port (current-input-port)))
         (elems (string->number (read-line port)))
         (s (set (redis-set-comparator))))
    (generator-for-each
     (lambda (i)
       (set-adjoin! s (redis-read-reply port)))
     (make-range-generator 0 elems))
    s))
;; read-redis-set ends here

;; Attributes
;; The attribute type is exactly like the Map type, but instead of the ~%~ first byte, the ~|~ byte is used. Attributes describe a dictionary exactly like the Map type, however the client should not consider such a dictionary part of the reply, but just auxiliary data that is used in order to augment the reply.

;; This library returns two values in this case, the first value being the actual data reply from redis, the second one being the attributes.

;; #+name: read-redis-with-attributes

;; [[file:redis.org::read-redis-with-attributes][read-redis-with-attributes]]
(define (read-redis-with-attributes #!optional port)
  (let* ((port (or port (current-input-port)))
         (attributes (read-redis-map port)))
    (values (redis-read-reply port) attributes)))
;; read-redis-with-attributes ends here
