#!/usr/bin/env racket
#lang racket

(require "src/main.rkt"
         racket/cmdline)

(define dir #f)
(define date #f)
(define dest #f)
(define server #f)
(define prefix #f)

(command-line
 #:program "syncer"
 #:once-each
 [("-d" "--destination") destination
                         "Destination directory for modified files"
                         (set! dest destination)]
 [("-s" "--server") server-url
                   "Server URL for uploading files (defaults to prometheus.statsbiblioteket.dk if -u is used)"
                   (set! server server-url)]
 [("-u" "--upload") "Upload files to server"
                   (set! server #t)]
 [("-p" "--prefix") dir-prefix
                   "Only process files within the specified directory prefix"
                   (set! prefix dir-prefix)]
 #:args ([directory "Directory to check"]
         [date-str "Date in format dd/mm/yy"])
 (set! dir directory)
 (set! date date-str))

(module+ main
  (sync dir date dest server prefix))