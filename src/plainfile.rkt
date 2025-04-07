#lang racket

(require racket/date
         racket/path
         racket/file
         file/md5
         racket/serialize)

(provide (all-defined-out))

;; Global hash for storing file MD5 values
;; Key: file path (string)
;; Value: (cons md5-hash last-modified-time)
(define file-md5-table (make-hash))

;; Root directory for serialization
(define root-directory (make-parameter #f))

;; File name for the serialized hash table
(define hash-file-name "file-hashes.dat")

;; Set the root directory
(define (set-root-directory! dir)
  (root-directory dir))

;; Get the full path to the hash file
(define (get-hash-file-path)
  (build-path (root-directory) hash-file-name))

;; Calculate MD5 hash for a file
(define (get-file-md5 file-path)
  (let ([path-obj (if (string? file-path)
                      (string->path file-path)
                      file-path)]
        [path-str (if (string? file-path)
                      file-path
                      (path->string file-path))])
    (if (file-exists? path-obj)
        (md5 path-str)  ; Use the string path with md5
        #f)))

;; Store MD5 hash for a file
(define (store-file-md5! file-path)
  (let* ([path-obj (if (string? file-path)
                       (string->path file-path)
                       file-path)]
         [path-str (path->string path-obj)]
         [md5-hash (get-file-md5 path-obj)]
         [mod-time (file-or-directory-modify-seconds path-obj)])
    (when md5-hash
      (hash-set! file-md5-table path-str (cons md5-hash mod-time)))
    md5-hash))

;; Get stored MD5 hash for a file (returns #f if not stored)
(define (get-stored-file-md5 file-path)
  (let* ([path-str (if (string? file-path)
                       file-path
                       (path->string file-path))]
         [entry (hash-ref file-md5-table path-str #f)])
    (and entry (car entry))))

;; Get stored modification time for a file (returns #f if not stored)
(define (get-stored-file-mod-time file-path)
  (let* ([path-str (if (string? file-path)
                       file-path
                       (path->string file-path))]
         [entry (hash-ref file-md5-table path-str #f)])
    (and entry (cdr entry))))

;; Check if file has changed by comparing MD5 hashes
(define (file-changed? file-path)
  (let* ([path-obj (if (string? file-path)
                       (string->path file-path)
                       file-path)]
         [path-str (path->string path-obj)]
         [stored-entry (hash-ref file-md5-table path-str #f)])
    (if stored-entry
        (let* ([stored-md5 (car stored-entry)]
               [current-md5 (get-file-md5 path-obj)])
          (not (equal? stored-md5 current-md5)))
        #t))) ; If not in hash, consider it changed

;; Serialize the hash table to a file
(define (serialize-hash-table!)
  (when (root-directory)
    (let ([hash-file (get-hash-file-path)])
      (displayln (format "Serializing hash table to ~a" hash-file))
      (with-output-to-file hash-file
        #:exists 'replace
        (lambda ()
          (write (serialize file-md5-table))))
      (displayln (format "Serialized ~a entries" (hash-count file-md5-table))))))

;; Deserialize the hash table from a file
(define (deserialize-hash-table!)
  (when (root-directory)
    (let ([hash-file (get-hash-file-path)])
      (when (file-exists? hash-file)
        (displayln (format "Loading hash table from ~a" hash-file))
        (with-handlers ([exn:fail? (lambda (e)
                                     (displayln (format "Error loading hash table: ~a" (exn-message e)))
                                     (displayln "Starting with empty hash table"))])
          (let ([loaded-table (with-input-from-file hash-file
                                (lambda () (deserialize (read))))])
            (set! file-md5-table loaded-table)
            (displayln (format "Loaded ~a entries" (hash-count file-md5-table)))))))))

;; Update hash table with a file's current MD5
(define (update-file-hash! file-path)
  (store-file-md5! file-path))

;; Initialize the hash table system
(define (initialize-hash-system! root-dir)
  (set-root-directory! root-dir)
  (deserialize-hash-table!))

;; Save the current state of the hash table
(define (save-hash-system!)
  (serialize-hash-table!))

;; Process a single file, checking if it has changed based on MD5 hash
;; Returns #t if the file has changed, #f otherwise
(define (process-file-md5 file-path)
  (let ([changed? (file-changed? file-path)])
    (when changed?
      (update-file-hash! file-path)
      (displayln (format "~a: MD5 changed, updating hash" file-path)))
    changed?))
