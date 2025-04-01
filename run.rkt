#!/usr/bin/env racket
#lang racket

(require "src/main.rkt"
         racket/cmdline)

(define dir #f)
(define date #f)

(command-line
 #:program "syncer"
 #:args ([directory "Directory to check"]
         [date-str "Date in format dd/mm/yy"])
 (set! dir directory)
 (set! date date-str))

(module+ main
  (sync dir date))