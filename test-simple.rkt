#!/usr/bin/env racket
#lang racket

(require racket/tcp)

;; Super simple test script that doesn't use our library
;; Just to verify basic netcat connectivity

(define (simple-test)
  (displayln "Testing simple TCP connection to localhost:8080")
  
  (with-handlers ([exn:fail? 
                   (lambda (e)
                     (displayln "ERROR: Could not connect to server")
                     (displayln (exn-message e))
                     (exit 1))])
    
    (displayln "Opening connection...")
    (define-values (in out) (tcp-connect "localhost" 8080))
    (displayln "Connection established successfully!")
    
    (displayln "Sending a simple HTTP request...")
    (display "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n" out)
    (flush-output out)
    
    (displayln "Request sent. Closing connection...")
    (close-output-port out)
    (close-input-port in)
    
    (displayln "Test completed successfully!"))

(module+ main
  (simple-test))