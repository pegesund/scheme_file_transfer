#!/usr/bin/env racket
#lang racket

(require "src/main.rkt")

;; Test script for testing HTTPS upload functionality
;; This uploads a small test file to a public HTTPS server

;; Main test function
(define (test-https)
  (displayln "=== HTTPS UPLOAD TEST ===")
  (displayln "Testing uploading to an HTTPS endpoint")
  
  ;; Create a temporary test file
  (define temp-file (make-temporary-file))
  (with-output-to-file temp-file #:exists 'truncate
    (lambda () (display "This is a test file for HTTPS upload")))
  
  (displayln (format "Created test file at: ~a" temp-file))
  
  ;; Attempt to upload to an HTTPS server
  (displayln "Attempting to upload to https://httpbin.org/post")
  (displayln "This is a test-only service that echoes back your request")
  
  ;; Note: This is intentionally using httpbin.org which is a test service
  ;; that will accept the upload but not actually store the file
  (upload-file temp-file "https://httpbin.org/post")
  
  ;; Clean up
  (when (file-exists? temp-file)
    (delete-file temp-file)
    (displayln "Deleted temporary test file"))
  
  (displayln "HTTPS test completed - the test is successful if no SSL errors occurred"))

;; Run the test
(module+ main
  (test-https))