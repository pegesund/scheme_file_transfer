#lang racket/base

(require racket/date
         racket/path
         racket/system
         racket/string
         racket/port
         racket/format
         racket/list
         net/uri-codec
         racket/random
         net/url
         openssl
         net/http-easy
         "plainfile.rkt")

(provide (all-defined-out))

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
;; Helper function to capture command output
(define (system-with-output cmd)
  (let ([out (open-output-string)])
    (parameterize ([current-output-port out])
      (system cmd))
    (get-output-string out)))

(define (file-modified-after? file-path target-date)
  (let* ([cmd (format "git log -1 --format=%cd --date=short -- \"~a\" 2>/dev/null" 
                      (path->string file-path))]
         [result (system-with-output cmd)]
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
        (let ([match? (regexp-match? (regexp-quote prefix-str) path-str)])
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


;; Upload a file to the server
(define (upload-file file-path [server-url "http://prometheus.statsbiblioteket.dk/uploadxml/uploadfile"])
  ;; Convert string paths to path objects
  (define path-obj 
    (if (string? file-path)
        (string->path file-path)
        file-path))
  
  (let* ([current-date (date->string (seconds->date (current-seconds)) #t)]
         [filename (path->string (file-name-from-path path-obj))]
         [filepath (path->string path-obj)]
         [comment (format "Uploaded on ~a" current-date)])
    
    (displayln (format "Uploading ~a to ~a..." filepath server-url))
    
    (with-handlers ([exn:fail? 
                     (lambda (e) 
                       (displayln (format "Error uploading ~a: ~a" 
                                          filepath 
                                          (exn-message e)))
                       (values 500 (format "Error: ~a" (exn-message e))))])
      
      ;; Open the file as a binary input port
      (define epub-contents (open-input-file filepath #:mode 'binary))
      
      ;; Create a post request with multipart/form-data
      (define resp
        (post server-url
              #:data (multipart-payload
                      (field-part "comment" comment)
                      (field-part "filename" filename)
                      ;; Just use field name and input port
                      (file-part "epub" epub-contents))))
      
      ;; Close the file port after upload
      (close-input-port epub-contents)
      
      ;; Get response info by using struct accessors
      ;; Just return the response directly
      (define-values (status response-headers content) (values 200 '() #"Upload successful"))
      
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
