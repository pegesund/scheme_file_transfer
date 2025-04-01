#lang racket

(require racket/date
         racket/path
         racket/system)

(provide (all-defined-out))

;; Parse date string in dd/mm/yy format
(define (parse-date date-str)
  (let* ([parts (string-split date-str "/")]
         [day (string->number (list-ref parts 0))]
         [month (string->number (list-ref parts 1))]
         [year (+ 2000 (string->number (list-ref parts 2)))])
    (seconds->date (find-seconds 0 0 0 day month year))))

;; Check if a file was modified after the specified date using git
(define (file-modified-after? file-path target-date)
  (let* ([cmd (format "git log -1 --format=%cd --date=short -- \"~a\" 2>/dev/null" 
                      (path->string file-path))]
         [result (with-output-to-string (lambda () (system cmd)))]
         [git-date-str (string-trim result)])
    (if (string=? git-date-str "")
        ; If not in git or no commits, fall back to file system date
        (let ([file-date (file-or-directory-modify-seconds file-path)])
          (displayln (format "~a: Not in git, using file system date ~a" 
                             file-path 
                             (date->string (seconds->date file-date))))
          #t) ; Just assuming true for now if not in git
        ; Parse git date (format: YYYY-MM-DD)
        (let* ([date-parts (string-split git-date-str "-")]
               [year (string->number (list-ref date-parts 0))]
               [month (string->number (list-ref date-parts 1))]
               [day (string->number (list-ref date-parts 2))])
          (displayln (format "~a: Git date: ~a" file-path git-date-str))
          #t)))) ; Just returning true for now until we implement comparison

;; Process a directory recursively
(define (process-directory dir target-date)
  (for ([path (in-directory dir)])
    (when (file-exists? path)
      (file-modified-after? path target-date))))

;; Main functionality
(define (sync directory date-str)
  (displayln (format "Checking directory: ~a for changes after: ~a" directory date-str))
  (let ([target-date (parse-date date-str)])
    (process-directory directory target-date)))
