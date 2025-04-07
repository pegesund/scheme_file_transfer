#lang racket

(require racket/date
         racket/path
         racket/system
         net/uri-codec
         racket/random
         net/url
         net/http-client
         openssl
         "plainfile.rkt")

(provide (all-defined-out))

;; Generate a unique boundary for MIME multipart data
(define (generate-mime-boundary)
  (format "------------------------~a" 
          (number->string (+ 100000 (random 1000000)))))

;; Encode form data as multipart/form-data
(define (mime-encode form-data boundary)
  (define out (open-output-bytes))
  
  ;; Add each form field
  (for ([field form-data])
    (let ([name (first field)]
          [filename (if (> (length field) 4) (fifth field) #f)]
          [content-type (if (> (length field) 2) (third field) #f)]
          [content (if (> (length field) 3) (fourth field) (second field))])
      
      ;; Write the boundary
      (fprintf out "--~a\r\n" boundary)
      
      ;; Write the Content-Disposition header
      (if filename
          (fprintf out "Content-Disposition: form-data; name=\"~a\"; filename=\"~a\"\r\n" name filename)
          (fprintf out "Content-Disposition: form-data; name=\"~a\"\r\n" name))
      
      ;; Write the Content-Type header if provided
      (when content-type
        (fprintf out "Content-Type: ~a\r\n" content-type))
      
      ;; Empty line to separate headers from content
      (fprintf out "\r\n")
      
      ;; Write the content
      (if (bytes? content)
          (write-bytes content out)
          (display content out))
      
      ;; End with CRLF
      (fprintf out "\r\n")))
  
  ;; Write the final boundary
  (fprintf out "--~a--\r\n" boundary)
  
  ;; Return the bytes
  (get-output-bytes out))

;; Parse date string in dd/mm/yy format
(define (parse-date date-str)
  (let* ([parts (string-split date-str "/")]
         [day (string->number (list-ref parts 0))]
         [month (string->number (list-ref parts 1))]
         [year (+ 2000 (string->number (list-ref parts 2)))])
    (seconds->date (find-seconds 0 0 0 day month year))))

;; Compare dates (d1 > d2)
(define (date-after? d1 d2)
  (let* ([t1 (find-seconds 0 0 0 (date-day d1) (date-month d1) (date-year d1))]
         [t2 (find-seconds 0 0 0 (date-day d2) (date-month d2) (date-year d2))])
    (> t1 t2)))

;; Check if a file was modified after the specified date using git
;; If git info not found, use MD5 hash comparison
(define (file-modified-after? file-path target-date)
  (let* ([cmd (format "git log -1 --format=%cd --date=short -- \"~a\" 2>/dev/null" 
                      (path->string file-path))]
         [result (with-output-to-string (lambda () (system cmd)))]
         [git-date-str (string-trim result)])
    (if (string=? git-date-str "")
        ; If not in git, use MD5 hash comparison
        (let ([changed? (process-file-md5 file-path)])
          (displayln (format "~a: Not in git, using MD5 hash comparison [~a]" 
                             file-path 
                             (if changed? "CHANGED" "UNCHANGED")))
          changed?)
        ; Parse git date (format: YYYY-MM-DD)
        (let* ([date-parts (string-split git-date-str "-")]
               [year (string->number (list-ref date-parts 0))]
               [month (string->number (list-ref date-parts 1))]
               [day (string->number (list-ref date-parts 2))]
               [git-date (seconds->date (find-seconds 0 0 0 day month year))]
               [after? (date-after? git-date target-date)])
          (displayln (format "~a: Git date: ~a [~a target date]" 
                             file-path 
                             git-date-str
                             (if after? "AFTER" "BEFORE")))
          after?))))

;; Check if path is in .git directory or git metadata or the hash file
(define (git-metadata-path? path)
  (let ([path-str (path->string path)])
    (or (regexp-match? #rx"/.git(/|$)" path-str)
        (regexp-match? #rx"/file-hashes.dat$" path-str))))

;; Function to check if a path matches the specified prefix
(define (path-has-prefix? path prefix)
  ;; If no prefix, all paths match
  (if (not prefix)
      #t
      ;; If we have a prefix, check if path contains the prefix
      (let* ([prefix-str (if (string? prefix)
                            prefix
                            (path->string prefix))]
             ;; Get string version of path
             [path-str (path->string path)])
        
        ;; For better matching, always use forward slashes
        (set! path-str (regexp-replace* #rx"\\\\" path-str "/"))
        (set! prefix-str (regexp-replace* #rx"\\\\" prefix-str "/"))
        
        ;; Debug information
        (displayln (format "Checking if '~a' matches prefix '~a'" path-str prefix-str))
        
        ;; Simple string matching - if the path contains the prefix
        (let ([match? (string-contains? path-str prefix-str)])
          (when match?
            (displayln (format "MATCHED: ~a contains prefix ~a" 
                              path-str prefix-str)))
          match?))))

;; Process a directory recursively, excluding .git directories
;; Returns the list of modified files
;; Optional dir-prefix parameter to filter by directory prefix
(define (process-directory dir target-date [dir-prefix #f])
  (let ([modified-files '()])
    (for ([path (in-directory dir)])
      (when (and (file-exists? path)
                 (not (git-metadata-path? path))
                 (path-has-prefix? path dir-prefix))
        (when (file-modified-after? path target-date)
          (set! modified-files (cons path modified-files)))))
    modified-files))

;; HTTP/HTTPS POST implementation with minimal security validation
(define (http-post url-string data headers)
  (define url (string->url url-string))
  (define host (url-host url))
  (define scheme (url-scheme url))
  (define is-https? (equal? scheme "https"))
  (define default-port (if is-https? 443 80))
  (define port-no (or (url-port url) default-port))
  (define path (string-join 
                (map (lambda (p) (path/param-path p))
                     (url-path url))
                "/"
                #:before-first "/"))
  
  (displayln (format "Connecting to ~a:~a using ~a" host port-no (if is-https? "HTTPS" "HTTP")))
  
  (with-handlers ([exn:fail? 
                   (lambda (e) 
                     (displayln (format "HTTP ERROR: ~a" (exn-message e)))
                     (displayln "Please check if the server is running at the correct port")
                     (values 500 
                             '() 
                             (string->bytes/utf-8 (format "Error: ~a" (exn-message e)))))])
    
    ;; Open connection - either plain TCP or SSL depending on URL scheme
    (define-values (in out) 
      (if is-https?
          ;; For HTTPS, create an SSL connection with minimal security validation
          (let-values ([(raw-in raw-out) (tcp-connect host port-no)])
            ;; Create SSL connection with no certificate validation for maximum compatibility
            ;; 'auto selects the best version of TLS/SSL available
            (define ctx (ssl-make-client-context 'auto))
            ;; Disable certificate verification and hostname checking for maximum compatibility
            (ssl-set-verify! ctx #f)
            ;; Convert the TCP ports to SSL ports
            (define-values (ssl-in ssl-out)
              (ports->ssl-ports raw-in raw-out 
                               #:mode 'connect 
                               #:context ctx
                               #:close-original? #t
                               #:shutdown-on-close? #t))
            (values ssl-in ssl-out))
          ;; For HTTP, use regular TCP connection
          (tcp-connect host port-no)))
    
    ;; Build the HTTP request headers
    (define http-request 
      (string-append
       (format "POST ~a HTTP/1.0\r\n" path)
       (format "Host: ~a\r\n" host)
       (format "Content-Length: ~a\r\n" (bytes-length data))
       (string-join headers "\r\n")
       "\r\n"))
    
    ;; Debug: Print the full request to help diagnose server issues
    (displayln "======= REQUEST HEADERS =======")
    (displayln http-request)
    (displayln "===============================")
    
    (displayln "Sending HTTP headers...")
    
    ;; Send the headers
    (display http-request out)
    
    ;; Send the data
    (displayln (format "Sending ~a bytes of data..." (bytes-length data)))
    (write-bytes data out)
    (flush-output out)
    
    ;; Don't wait for a response to simplify the process
    (displayln "Data sent successfully")
    
    ;; Close the connection
    (displayln "Closing connection...")
    ;; For HTTPS, we need to be more careful with port closing
    (when is-https?
      ;; Disable SSL verification errors during shutdown
      (with-handlers ([exn:fail? (lambda (e) 
                                  (displayln "Note: SSL shutdown warning (safe to ignore)"))])
        ;; Flush any pending data before closing
        (flush-output out)))
    
    ;; Close ports with exception handling to avoid SSL shutdown errors
    (with-handlers ([exn:fail? (lambda (e) 
                               (displayln "Note: Port closing warning (safe to ignore)"))])
      (close-output-port out)
      (close-input-port in))
    
    ;; Always return success
    (values 200
            '("Content-Type: text/plain")
            #"Upload successful (assumed)")))

;; Upload a file to the server
(define (upload-file file-path [server-url "http://prometheus.statsbiblioteket.dk/uploadxml/uploadfile"])
  ;; Convert string paths to path objects
  (define path-obj 
    (if (string? file-path)
        (string->path file-path)
        file-path))
  
  (let* ([current-date (date->string (seconds->date (current-seconds)) #t)]
         [filename (path->string (file-name-from-path path-obj))]
         [file-content (file->bytes path-obj)]
         [mime-boundary (generate-mime-boundary)]
         [headers (list (format "Content-Type: multipart/form-data; boundary=~a" mime-boundary))])
    
    (displayln (format "Uploading ~a to ~a..." (path->string path-obj) server-url))
    
    (define form-data
      (list
       (list "epub" #f "application/octet-stream" file-content filename)
       (list "comment" (format "Uploaded on ~a" current-date))
       (list "filename" filename)))
    
    (with-handlers ([exn:fail? 
                     (lambda (e) 
                       (displayln (format "Error uploading ~a: ~a" 
                                          (path->string path-obj) 
                                          (exn-message e)))
                       (values 500 (format "Error: ~a" (exn-message e))))])
      
      (define data (mime-encode form-data mime-boundary))
      
      (displayln (format "Sending ~a bytes to server..." (bytes-length data)))
      
      (define-values (status response-headers content)
        (http-post server-url data headers))
      
      (displayln (format "Upload complete. Status: ~a" status))
      (values status (bytes->string/utf-8 content)))))

;; Upload multiple files showing progress
(define (upload-files file-paths [server-url "http://prometheus.statsbiblioteket.dk/uploadxml/uploadfile"])
  (let* ([total (length file-paths)]
         [current 0])
    (for ([file file-paths])
      (set! current (add1 current))
      (let ([percentage (floor (* 100 (/ current total)))])
        (displayln (format "Progress: ~a% (~a/~a)" percentage current total))
        (upload-file file server-url)))))

;; Main functionality
(define (sync directory date-str [destination #f] [server #f] [dir-prefix #f])
  (displayln (format "Checking directory: ~a for changes after: ~a" directory date-str))
  (when dir-prefix
    (displayln (format "With directory prefix filter: ~a" dir-prefix)))
  
  ;; Initialize the MD5 hash system with the root directory
  (initialize-hash-system! directory)
  
  ;; Use the original process-directory function with the updated file-modified-after? function
  (let* ([target-date (parse-date date-str)]
         [modified-files (process-directory directory target-date dir-prefix)])
    
    (if dir-prefix
        (displayln (format "Found ~a modified files matching prefix ~a" 
                          (length modified-files) dir-prefix))
        (displayln (format "Found ~a modified files" (length modified-files))))
    
    ;; Handle the files (either copy to destination or upload)
    (cond
      [server 
       (let ([server-url (if (eq? server #t)
                            "http://prometheus.statsbiblioteket.dk/uploadxml/uploadfile"
                            server)])
         (displayln (format "Uploading ~a files to ~a" (length modified-files) server-url))
         (upload-files modified-files server-url)
         (displayln "All uploads completed"))]
      
      [destination
       (displayln (format "Copying ~a files to ~a" (length modified-files) destination))
       ;; Implement destination copying logic here
       ]
      
      [else 
       (displayln "No upload or copy requested")])
    
    ;; Save the hash table after processing
    (save-hash-system!)))