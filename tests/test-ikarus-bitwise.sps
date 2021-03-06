;;; -*- coding: utf-8-unix -*-
;;;
;;;Part of: Vicare
;;;Contents: tests
;;;Date: Tue Oct 18, 2011
;;;
;;;Abstract
;;;
;;;	Tests  from  the  file  "scheme/tests/bitwise.ss"  file  in  the
;;;	original Ikarus distribution.
;;;
;;;Copyright (C) 2006-2010 Abdulaziz Ghuloum <aghuloum@cs.indiana.edu>
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under the terms of the  GNU General Public License as published by
;;;the Free Software Foundation, either version 3 of the License, or (at
;;;your option) any later version.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should  have received  a copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!ikarus
(import (vicare)
  (libtest ikarus-test-framework)
  (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Ikarus bitwise operations\n")


;;;; helpers

(define-syntax test-base-case
  (syntax-rules ()
    ((_ op i0 i1 r)
     (check (op i0 i1) => r))))

(define (generate-numbers)
  (define N 68)
  (define (n* n i)
    (if (zero? i)
	'()
      (cons n (n* (bitwise-arithmetic-shift-left n 1) (- i 1)))))
  (append (n* 1 N)
	  (n* -1 N)
	  (map sub1 (n* 1 N))
	  (map sub1 (n* -1 N))
	  (map add1 (n* 1 N))
	  (map add1 (n* -1 N))))

(define (one-bit n)
  (if (even? n) 0 1))

(define (unit? n)
  (or (= n 0) (= n -1)))

(define (trusted op n1 n2)
  (if (and (unit? n1) (unit? n2))
      (op n1 n2)
    (+ (one-bit (op (one-bit n1) (one-bit n2)))
       (bitwise-arithmetic-shift-left
	(trusted op
		 (bitwise-arithmetic-shift-right n1 1)
		 (bitwise-arithmetic-shift-right n2 1))
	1))))

(define (test-case op)
  (define ls (generate-numbers))
  (define id 0)
  (for-each (lambda (n1)
	      (for-each (lambda (n2)
			  (let ((r0 (op n1 n2))
				(r1 (trusted op n1 n2)))
			    (check r0 => r1)
			    (unless (= r0 r1)
			      (printf "id=~s ~x ~x ~x ~x\n" id n1 n2 r0 r1)
			      (error 'test-bitwise-op
				"mismatch/op/a0/a1/got/expected" op n1 n2 r0 r1))
			    (set! id (+ id 1))))
		ls))
    ls))


;;;; go

(test-base-case bitwise-and 0 0 0)
(test-base-case bitwise-and 0 1 0)
(test-base-case bitwise-and 1 0 0)
(test-base-case bitwise-and 1 1 1)

(test-base-case bitwise-ior 0 0 0)
(test-base-case bitwise-ior 0 1 1)
(test-base-case bitwise-ior 1 0 1)
(test-base-case bitwise-ior 1 1 1)

(test-base-case bitwise-xor 0 0 0)
(test-base-case bitwise-xor 0 1 1)
(test-base-case bitwise-xor 1 0 1)
(test-base-case bitwise-xor 1 1 0)

;;; --------------------------------------------------------------------

(test-case bitwise-and)
(test-case bitwise-ior)
(test-case bitwise-xor)


;;;; done

(check-report)

;;; end of file
