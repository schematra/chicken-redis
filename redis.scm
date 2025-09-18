;; API


;; [[file:redis.org::*API][API:1]]
(define-library (redis)
  (import (chicken base))
  (export redis-connect
          redis-disconnect
          redis-run
          redis-run-proc
	  redis-read-reply ;; used in pub-sub

          make-redis-connection
          redis-connection?
          redis-connection-input
          redis-connection-output


          &redis-error
          redis-error?
          redis-error-message

          redis-set-comparator)
  (begin
    (include-relative "redis-impl.scm")))
;; API:1 ends here
