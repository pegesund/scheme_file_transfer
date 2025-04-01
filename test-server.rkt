#!/usr/bin/env racket
#lang racket

;; Ultra simple HTTP server using just TCP sockets
;; Avoids web-server libraries entirely to prevent header parsing errors

(require racket/tcp
         racket/port
         racket/system
         racket/string)

;; Extract the boundary and parse the multipart form data
(define (extract-content-type-header lines)
  (for/first ([line lines]
              #:when (regexp-match? #rx"^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]:" line))
    line))

(define (extract-boundary content-type)
  (define match (regexp-match #rx"boundary=(.+)(?:;|$)" content-type))
  (and match (cadr match)))

(define (split-at-double-newline str)
  (define match (regexp-match-positions #rx"\r\n\r\n" str))
  (if match
      (let* ([pos (cdar match)]
             [headers (substring str 0 pos)]
             [body (substring str (+ pos 4))])  ; Skip 4 chars for \r\n\r\n
        (values headers body))
      ; Try with just \n\n if \r\n\r\n not found
      (let ([match2 (regexp-match-positions #rx"\n\n" str)])
        (if match2
            (let* ([pos (cdar match2)]
                   [headers (substring str 0 pos)]
                   [body (substring str (+ pos 2))])  ; Skip 2 chars for \n\n
              (values headers body))
            (values str "")))))

;; Safely convert bytes to string, handling non-UTF8 bytes
(define (safe-bytes->string bytes)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     ;; Fall back to replacing invalid chars with ?
                     (bytes->string/utf-8 bytes #:error-char #\?))])
    (bytes->string/utf-8 bytes)))

;; Extract boundary from HTTP request
(define (extract-request-boundary request-str)
  (define lines (string-split request-str "\r\n"))
  (define content-type (extract-content-type-header lines))
  (and content-type (extract-boundary content-type)))

(define (handle-upload data)
  ;; First, get the header portion to extract boundary
  (define header-end (regexp-match-positions #rx"\r\n\r\n" data))
  (when header-end
    (define header-part (substring data 0 (cdar header-end)))
    (define boundary (extract-request-boundary header-part))
    
    (when boundary
      (displayln (format "Boundary found: ~a" boundary))
      (define boundary-marker (string-append "--" boundary))
      
      ;; Split by boundary
      (define parts (regexp-split (regexp-quote boundary-marker) data))
      (displayln (format "Found ~a parts in the request" (length parts)))
      
      ;; Process parts (skipping first part which is before first boundary)
      (for ([part (in-list (cdr parts))] 
            [i (in-naturals)])
        (when (> (string-length part) 10) ; Skip too short parts
          (displayln (format "Processing part #~a" i))
          
          ;; Split headers and content
          (define-values (headers content) (split-at-double-newline part))
          
          ;; Look for filename in Content-Disposition header
          (define filename-match 
            (regexp-match #rx"filename=\"([^\"]+)\"" headers))
          (define name-match 
            (regexp-match #rx"name=\"([^\"]+)\"" headers))
          
          (when (and filename-match name-match)
            (define name (cadr name-match))
            (define filename (cadr filename-match))
            (define size (string-length content))
            
            (displayln (format "Received file: ~a (~a bytes)" filename size))
            
            ;; Save to temp file
            (define temp-path (build-path (find-system-path 'temp-dir) filename))
            (with-output-to-file temp-path #:exists 'replace
              (lambda () (display content)))
            
            (displayln (format "Saved to: ~a" temp-path)))))
      
      ;; Return the number of files processed
      (length parts))))

;; Simple HTTP server
(define (start-server [port 8080])
  (define listener (tcp-listen port 5 #t))
  (displayln (format "Starting simple HTTP server on port ~a" port))
  (displayln "Ready to receive file uploads at: http://localhost:8080/uploadxml/uploadfile")
  (displayln "Press Ctrl+C to stop the server")
  
  (let loop ()
    (define-values (in out) (tcp-accept listener))
    
    ;; Handle each connection in a separate thread
    (thread
     (lambda ()
       (with-handlers ([exn:fail? 
                       (lambda (e) 
                         (displayln (format "ERROR: ~a" (exn-message e))))])
         (define request-bytes (read-bytes 10000000 in))  ;; Read up to 10MB
         
         ;; First convert the header part safely to check if it's a POST request
         (define header-end-pos 
           (regexp-match-positions #rx#"\r\n\r\n" request-bytes))
         
         (when header-end-pos
           (define header-bytes 
             (subbytes request-bytes 0 (cdar header-end-pos)))
           (define header-str (bytes->string/utf-8 header-bytes))
           
           ;; Check if it's POST to /uploadxml/uploadfile
           (when (regexp-match? #rx"^POST /uploadxml/uploadfile HTTP" header-str)
             (displayln "Received POST request to /uploadxml/uploadfile")
             
             ;; Convert entire request to string (may have binary data)
             (define request-str (safe-bytes->string request-bytes))
             
             ;; Process the upload
             (handle-upload request-str)))
         
         ;; Always send a simple HTTP response
         (display "HTTP/1.1 200 OK\r\n" out)
         (display "Content-Type: text/html\r\n" out)
         (display "Connection: close\r\n" out)
         (display "\r\n" out)
         (display "<html><body><h1>Request processed</h1></body></html>" out)
         
         ;; Close the connection
         (close-output-port out)
         (close-input-port in))))
    
    ;; Continue accepting connections
    (loop)))

;; Make executable
(module+ main
  ;; Convert command-line arguments to a list
  (define args (vector->list (current-command-line-arguments)))
  
  ;; Check if we're running in compile mode (-c)
  (define compile-mode? (member "-c" args))
  
  ;; Only start server if not in compile mode
  (unless compile-mode?
    (start-server)))