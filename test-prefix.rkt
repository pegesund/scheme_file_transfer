#!/usr/bin/env racket
#lang racket

(require "src/main.rkt")

;; Test script for testing just the directory prefix filter
;; to upload only files in a specific directory

;; Get a date in the past to ensure files are detected
(define (get-test-date-str)
  ; Use January 1, 2020 to ensure all files are newer
  (format "1/1/20"))

;; Main test function
(define (test-prefix)
  (displayln "=== DIRECTORY PREFIX FILTER TEST ===")
  (displayln "Make sure test-server.rkt is running in another terminal")
  
  ;; Check if server is running
  (displayln "Checking server connection...")
  (with-handlers ([exn:fail? 
                   (lambda (e)
                     (displayln "ERROR: Could not connect to localhost:8080")
                     (displayln "Please start the test-server.rkt first:")
                     (displayln "  ./test-server.rkt")
                     (exit 1))])
    (define-values (in out) (tcp-connect "localhost" 8080))
    (display "TEST CONNECTION" out)
    (flush-output out)
    (close-input-port in)
    (close-output-port out)
    (displayln "Server is running and accepting connections"))
  
  ;; Get current directory
  (define current-dir (current-directory))
  
  (displayln "\nTesting directory prefix filter")
  (displayln "================================")
  (displayln (format "Will upload only files in 'petter' directory modified since ~a" (get-test-date-str)))
  (displayln "This should include ONLY petter/petter file")
  
  ;; Call the sync function with directory prefix filter
  (sync current-dir 
        (get-test-date-str)  
        #f  ; No destination directory
        "http://localhost:8080/uploadxml/uploadfile"  ; Server URL
        (build-path current-dir "petter"))  ; Only process files in petter/ directory
  
  (displayln "\nTest completed. Check the server terminal for upload information.")
  (displayln "You should see ONLY the 'petter' file being uploaded, nothing else."))

;; Run the test
(module+ main
  (test-prefix))