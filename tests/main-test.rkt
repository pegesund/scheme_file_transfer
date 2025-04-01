#lang racket
(require rackunit
         "../src/main.rkt")

(module+ test
  (test-case "Basic sync function test"
    (check-not-exn (lambda () (sync "/test/source" "/test/dest")))))