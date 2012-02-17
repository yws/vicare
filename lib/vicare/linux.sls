;;; -*- coding: utf-8-unix -*-
;;;
;;;Part of: Vicare
;;;Contents: Linux platform API
;;;Date: Mon Nov  7, 2011
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2011, 2012 Marco Maggi <marco.maggi-ipsu@poste.it>
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


(library (vicare linux)
  (export
    ;; process termination status
    waitid
    make-struct-siginfo_t		struct-siginfo_t?
    struct-siginfo_t-si_pid		struct-siginfo_t-si_uid
    struct-siginfo_t-si_signo		struct-siginfo_t-si_status
    struct-siginfo_t-si_code
    WIFCONTINUED

    ;; epoll
    epoll-create			epoll-create1
    epoll-ctl				epoll-wait
    epoll-event-alloc			epoll-event-size
    epoll-event-set-events!		epoll-event-ref-events
    epoll-event-set-data-ptr!		epoll-event-ref-data-ptr
    epoll-event-set-data-fd!		epoll-event-ref-data-fd
    epoll-event-set-data-u32!		epoll-event-ref-data-u32
    epoll-event-set-data-u64!		epoll-event-ref-data-u64

    ;; interprocess signals
    signalfd				read-signalfd-siginfo

    make-struct-signalfd-siginfo	struct-signalfd-siginfo?
    struct-signalfd-siginfo-ssi_signo	struct-signalfd-siginfo-ssi_errno
    struct-signalfd-siginfo-ssi_code	struct-signalfd-siginfo-ssi_pid
    struct-signalfd-siginfo-ssi_uid	struct-signalfd-siginfo-ssi_fd
    struct-signalfd-siginfo-ssi_tid	struct-signalfd-siginfo-ssi_band
    struct-signalfd-siginfo-ssi_overrun	struct-signalfd-siginfo-ssi_trapno
    struct-signalfd-siginfo-ssi_status	struct-signalfd-siginfo-ssi_int
    struct-signalfd-siginfo-ssi_ptr	struct-signalfd-siginfo-ssi_utime
    struct-signalfd-siginfo-ssi_stime	struct-signalfd-siginfo-ssi_addr
    )
  (import (vicare)
    (vicare syntactic-extensions)
    (vicare platform-constants)
    (prefix (vicare words)
	    words.)
    (prefix (vicare unsafe-capi)
	    capi.)
    (prefix (vicare unsafe-operations)
	    unsafe.))


;;;; arguments validation

(define-argument-validation (procedure who obj)
  (procedure? obj)
  (assertion-violation who "expected procedure as argument" obj))

(define-argument-validation (boolean who obj)
  (boolean? obj)
  (assertion-violation who "expected boolean as argument" obj))

(define-argument-validation (fixnum who obj)
  (fixnum? obj)
  (assertion-violation who "expected fixnum as argument" obj))

(define-argument-validation (positive-fixnum who obj)
  (and (fixnum? obj) (unsafe.fx< 0 obj))
  (assertion-violation who "expected positive fixnum as argument" obj))

(define-argument-validation (index who obj)
  (and (fixnum? obj) (unsafe.fx<= 0 obj))
  (assertion-violation who "expected fixnum index as argument" obj))

(define-argument-validation (string who obj)
  (string? obj)
  (assertion-violation who "expected string as argument" obj))

(define-argument-validation (pointer who obj)
  (pointer? obj)
  (assertion-violation who "expected pointer as argument" obj))

(define-argument-validation (false/pointer who obj)
  (or (not obj) (pointer? obj))
  (assertion-violation who "expected false or pointer as argument" obj))

;;; --------------------------------------------------------------------

(define-argument-validation (signed-int who obj)
  (words.signed-int? obj)
  (assertion-violation who "expected C language signed int as argument" obj))

(define-argument-validation (uint32 who obj)
  (words.word-u32? obj)
  (assertion-violation who "expected C language uint32 as argument" obj))

(define-argument-validation (uint64 who obj)
  (words.word-u64? obj)
  (assertion-violation who "expected C language uint64 as argument" obj))

;;; --------------------------------------------------------------------

(define-argument-validation (pid who obj)
  (fixnum? obj)
  (assertion-violation who "expected fixnum pid as argument" obj))

(define-argument-validation (signal who obj)
  (fixnum? obj)
  (assertion-violation who "expected fixnum signal code as argument" obj))

(define-argument-validation (file-descriptor who obj)
  (%file-descriptor? obj)
  (assertion-violation who "expected fixnum file descriptor as argument" obj))

(define-argument-validation (file-descriptor/-1 who obj)
  (and (fixnum? obj)
       (or (unsafe.fx=  obj -1)
	   (and (unsafe.fx>= obj 0)
		(unsafe.fx<  obj FD_SETSIZE))))
  (assertion-violation who "expected -1 or fixnum file descriptor as argument" obj))

(define-argument-validation (vector-of-signums who obj)
  (and (vector? obj) (vector-for-all fixnum? obj))
  (assertion-violation who "expected vector of signums as arguments" obj))


;;;; helpers

(define (%raise-errno-error who errno . irritants)
  (raise (condition
	  (make-error)
	  (make-errno-condition errno)
	  (make-who-condition who)
	  (make-message-condition (strerror errno))
	  (make-irritants-condition irritants))))

(define-inline (%file-descriptor? obj)
  ;;Do  what   is  possible  to  recognise   fixnums  representing  file
  ;;descriptors.
  ;;
  (and (fixnum? obj)
       (unsafe.fx>= obj 0)
       (unsafe.fx<  obj FD_SETSIZE)))


;;;; process termination status

(define-struct struct-siginfo_t
  (si_pid si_uid si_signo si_status si_code))

(define (waitid idtype id options)
  (define who 'waitid)
  (with-arguments-validation (who)
      ((fixnum  idtype)
       (fixnum	id)
       (fixnum	options))
    (capi.linux-waitid idtype id (make-struct-siginfo_t #f #f #f #f #f) options)))

(define (WIFCONTINUED status)
  (define who 'WIFCONTINUED)
  (with-arguments-validation (who)
      ((fixnum  status))
    (capi.linux-WIFCONTINUED status)))


;;;; epoll

(define epoll-create
  (case-lambda
   (()
    (epoll-create 16))
   ((size)
    (define who 'epoll-create)
    (with-arguments-validation (who)
	((signed-int	size))
      (let ((rv (capi.linux-epoll-create size)))
	(if (unsafe.fx<= 0 rv)
	    rv
	  (%raise-errno-error who rv size)))))))

(define (epoll-create1 flags)
  (define who 'epoll-create1)
  (with-arguments-validation (who)
      ((signed-int	flags))
    (let ((rv (capi.linux-epoll-create flags)))
      (if (unsafe.fx<= 0 rv)
	  rv
	(%raise-errno-error who rv flags)))))

(define epoll-ctl
  (case-lambda
   ((epfd op fd)
    (epoll-ctl epfd op fd #f))
   ((epfd op fd event)
    (define who 'epoll-ctl)
    (with-arguments-validation (who)
	((file-descriptor	epfd)
	 (fixnum		op)
	 (file-descriptor	fd)
	 (false/pointer		event))
      (let ((rv (capi.linux-epoll-ctl epfd op fd event)))
	(unless (unsafe.fxzero? rv)
	  (%raise-errno-error who rv epfd op fd event)))))))

(define (epoll-wait epfd event maxevents timeout-ms)
  (define who 'epoll-wait)
  (with-arguments-validation (who)
      ((file-descriptor		epfd)
       (pointer			event)
       (signed-int		maxevents)
       (signed-int		timeout-ms))
    (let ((rv (capi.linux-epoll-wait epfd event maxevents timeout-ms)))
      (if (unsafe.fx<= 0 rv)
	  rv
	(%raise-errno-error who rv epfd event maxevents timeout-ms)))))

;;; --------------------------------------------------------------------

(define (epoll-event-alloc number-of-entries)
  (define who 'epoll-event-alloc)
  (with-arguments-validation (who)
      ((positive-fixnum	number-of-entries))
    (let ((rv (capi.linux-epoll-event-alloc number-of-entries)))
      (or rv (%raise-errno-error who ENOMEM number-of-entries)))))

(define (epoll-event-size)
  (capi.linux-epoll-event-size))

;;; --------------------------------------------------------------------

(let-syntax
    ((define-epoll-event-field
       (syntax-rules ()
	 ((_ ?mutator ?accessor ?value-type ?mutator-func ?accessor-func)
	  (begin
	    (define (?mutator events-array index new-value)
	      (define who '?mutator)
	      (with-arguments-validation (who)
		  ((pointer		events-array)
		   (index		index)
		   (?value-type	new-value))
		(?mutator-func events-array index new-value)))
	    (define (?accessor events-array index)
	      (define who '?accessor)
	      (with-arguments-validation (who)
		  ((pointer		events-array)
		   (index		index))
		(?accessor-func events-array index))))))))

  (define-epoll-event-field
    epoll-event-set-events!
    epoll-event-ref-events
    uint32
    capi.linux-epoll-event-set-events!
    capi.linux-epoll-event-ref-events)

  (define-epoll-event-field
    epoll-event-set-data-ptr!
    epoll-event-ref-data-ptr
    pointer
    capi.linux-epoll-event-set-data-ptr!
    capi.linux-epoll-event-ref-data-ptr)

  (define-epoll-event-field
    epoll-event-set-data-fd!
    epoll-event-ref-data-fd
    file-descriptor
    capi.linux-epoll-event-set-data-fd!
    capi.linux-epoll-event-ref-data-fd)

  (define-epoll-event-field
    epoll-event-set-data-u32!
    epoll-event-ref-data-u32
    uint32
    capi.linux-epoll-event-set-data-u32!
    capi.linux-epoll-event-ref-data-u32)

  (define-epoll-event-field
    epoll-event-set-data-u64!
    epoll-event-ref-data-u64
    uint64
    capi.linux-epoll-event-set-data-u64!
    capi.linux-epoll-event-ref-data-u64)
  )


;;;; interprocess signals

(define-struct struct-signalfd-siginfo
  (ssi_signo	; 0
   ssi_errno	; 1
   ssi_code	; 2
   ssi_pid	; 3
   ssi_uid	; 4
   ssi_fd	; 5
   ssi_tid	; 6
   ssi_band	; 7
   ssi_overrun	; 8
   ssi_trapno	; 9
   ssi_status	; 10
   ssi_int	; 11
   ssi_ptr	; 12
   ssi_utime	; 13
   ssi_stime	; 14
   ssi_addr))	; 15

(define (%struct-signalfd-siginfo-printer S port sub-printer)
  (define-inline (%display thing)
    (display thing port))
  (%display "#[struct-signalfd-siginfo")
  (%display " ssi_signo=")	(%display (struct-signalfd-siginfo-ssi_signo S))
  (%display " ssi_errno=")	(%display (struct-signalfd-siginfo-ssi_errno S))
  (%display " ssi_code=")	(%display (struct-signalfd-siginfo-ssi_code S))
  (%display " ssi_pid=")	(%display (struct-signalfd-siginfo-ssi_pid S))
  (%display " ssi_uid=")	(%display (struct-signalfd-siginfo-ssi_uid S))
  (%display " ssi_fd=")		(%display (struct-signalfd-siginfo-ssi_fd S))
  (%display " ssi_tid=")	(%display (struct-signalfd-siginfo-ssi_tid S))
  (%display " ssi_band=")	(%display (struct-signalfd-siginfo-ssi_band S))
  (%display " ssi_overrun=")	(%display (struct-signalfd-siginfo-ssi_overrun S))
  (%display " ssi_trapno=")	(%display (struct-signalfd-siginfo-ssi_trapno S))
  (%display " ssi_status=")	(%display (struct-signalfd-siginfo-ssi_status S))
  (%display " ssi_int=")	(%display (struct-signalfd-siginfo-ssi_int S))
  (%display " ssi_ptr=")	(%display (struct-signalfd-siginfo-ssi_ptr S))
  (%display " ssi_utime=")	(%display (struct-signalfd-siginfo-ssi_utime S))
  (%display " ssi_stime=")	(%display (struct-signalfd-siginfo-ssi_stime S))
  (%display " ssi_addr=")	(%display (struct-signalfd-siginfo-ssi_addr S))
  (%display "]"))

(define (signalfd fd mask flags)
  (define who 'signalfd)
  (with-arguments-validation (who)
      ((file-descriptor/-1	fd)
       (vector-of-signums	mask)
       (fixnum			flags))
    (let ((rv (capi.linux-signalfd fd mask flags)))
      (if (unsafe.fx<= 0 rv)
	  rv
	(%raise-errno-error who rv fd mask flags)))))

(define (read-signalfd-siginfo fd)
  (define who 'read-signalfd-siginfo)
  (with-arguments-validation (who)
      ((file-descriptor	fd))
    (let* ((info (make-struct-signalfd-siginfo #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f))
	   (rv   (capi.linux-read-signalfd-siginfo fd info)))
      (cond ((unsafe.fxzero? rv)
	     info)
	    ((unsafe.fx= rv EAGAIN)
	     #f)
	    (else
	     (%raise-errno-error who rv fd))))))


;;;; done

(set-rtd-printer! (type-descriptor struct-signalfd-siginfo)	%struct-signalfd-siginfo-printer)

)

;;; end of file
