#!/usr/bin/env racket
#lang racket

(require "src/main.rkt")

;; Test script for uploading all files modified after a date
;; to a local server running on localhost:8080

;; Get a date in the past to ensure files are detected
(define (get-test-date-str)
  ; Use January 1, 2020 to ensure all files are newer
  (format "1/1/20"))

;; List some test files for upload
(define (list-test-files)
  (list 
    (build-path (current-directory) "README.md")
    (build-path (current-directory) "run.rkt")
    (build-path (current-directory) "info.rkt")
    (build-path (current-directory) "src/main.rkt")))

;; Main test function
(define (test-localhost)
  (displayln "=== FILE UPLOAD TEST TO LOCALHOST:8080 ===")
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
  
  (displayln "\nTest 1: Upload specific test files")
  (displayln "================================")
  
  ;; Use a background thread with timeout for specific files
  (define done-evt1 (make-semaphore 0))
  
  (thread
   (lambda ()
     ;; Upload specific test files
     (upload-files (list-test-files) "http://localhost:8080/uploadxml/uploadfile")
     (semaphore-post done-evt1)))
  
  ;; Wait for uploads to complete with a timeout
  (define result1 (sync/timeout 30 done-evt1))
  
  (if result1
      (displayln "\nTest 1 completed successfully!")
      (displayln "\nTest 1 timed out after 30 seconds"))
      
  (displayln "\nTest 2: Use sync function to find and upload files")
  (displayln "=========================================")
  (displayln (format "Will upload all files modified since ~a" (get-test-date-str)))
  (displayln "This will recursively scan the directory for modified files")
  
  ;; Use a background thread with timeout for sync function
  (define done-evt2 (make-semaphore 0))
  
  (thread
   (lambda ()
     ;; Call the sync function to find and upload all files
     (sync current-dir 
           (get-test-date-str)  
           #f  ; No destination directory
           "http://localhost:8080/uploadxml/uploadfile"  ; Server URL
           #f)  ; No directory prefix filter
     
     (semaphore-post done-evt2)))
  
  ;; Wait for uploads to complete with a timeout
  (define result2 (sync/timeout 30 done-evt2))
  
  (if result2
      (displayln "\nTest 2 completed successfully!")
      (displayln "\nTest 2 timed out after 30 seconds"))

  ;; Test 3: With directory prefix filter 
  (displayln "\nTest 3: Using directory prefix filter")
  (displayln "===================================")
  (displayln (format "Will upload only files in src/ directory modified since ~a" (get-test-date-str)))
  
  ;; Use a background thread with timeout for filtered sync
  (define done-evt3 (make-semaphore 0))
  
  (thread
   (lambda ()
     ;; Call the sync function with directory prefix filter
     (sync current-dir 
           (get-test-date-str)  
           #f  ; No destination directory
           "http://localhost:8080/uploadxml/uploadfile"  ; Server URL
           (build-path current-dir "src"))  ; Only process files in src/ directory
     
     (semaphore-post done-evt3)))
  
  ;; Wait for uploads to complete with a timeout
  (define result3 (sync/timeout 30 done-evt3))
  
  (if result3
      (displayln "\nTest 3 completed successfully!")
      (displayln "\nTest 3 timed out after 30 seconds"))
  
  (displayln "\nAll tests completed. Check the server terminal for upload information"))

;; Run the test
(module+ main
  (test-localhost))