;;; -*- coding: utf-8-unix -*-
;;;
;;;Ikarus Scheme -- A compiler for R6RS Scheme.
;;;Copyright (C) 2006,2007,2008  Abdulaziz Ghuloum
;;;Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software: you can  redistribute it and/or modify it under the
;;;terms  of the  GNU General  Public  License version  3  as published  by the  Free
;;;Software Foundation.
;;;
;;;This program is  distributed in the hope  that it will be useful,  but WITHOUT ANY
;;;WARRANTY; without  even the implied warranty  of MERCHANTABILITY or FITNESS  FOR A
;;;PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;;;
;;;You should have received a copy of  the GNU General Public License along with this
;;;program.  If not, see <http://www.gnu.org/licenses/>.


#!vicare
(library (ikarus records procedural)
  (export
    ;; bindings for (rnrs records procedural (6))
    make-record-type-descriptor		make-record-constructor-descriptor
    (rename (<rtd>? record-type-descriptor?))
    (rename (<rcd>? record-constructor-descriptor?))
    record-constructor			record-predicate
    record-accessor			record-mutator
    unsafe-record-accessor		unsafe-record-mutator

    ;; bindings for (rnrs records inspection (6))
    record?				record-rtd
    record-type-name			record-type-parent
    record-type-uid			record-type-generative?
    record-type-sealed?			record-type-opaque?
    record-field-mutable?
    record-type-field-names
    (rename (<rtd>-uids-list			record-type-uids-list)
	    (<rtd>-implemented-interfaces	record-type-implemented-interfaces))

    ;; bindings for (vicare system $records)

    ;; extension utility functions, non-R6RS
    make-record-type-descriptor-ex
    rtd-subtype?				record-type-all-field-names
    (rename (<rcd>-rtd				rcd-rtd)
	    (<rcd>-parent-rcd			rcd-parent-rcd))
    record=?					record!=?
    record-and-rtd?				$record-and-rtd?
    record-object?
    record-reset!
    record-ref					$record-ref
    ;;
    record-destructor				$record-destructor
    record-printer				$record-printer
    record-equality-predicate			$record-equality-predicate
    record-comparison-procedure			$record-comparison-procedure
    record-hash-function			$record-hash-function
    record-method-retriever			$record-method-retriever
    ;;
    record-type-destructor-set!			$record-type-destructor-set!
    record-type-destructor			$record-type-destructor
    record-type-printer				$record-type-printer
    record-type-printer-set!			$record-type-printer-set!
    record-type-equality-predicate		$record-type-equality-predicate
    record-type-equality-predicate-set!		$record-type-equality-predicate-set!
    record-type-comparison-procedure		$record-type-comparison-procedure
    record-type-comparison-procedure-set!	$record-type-comparison-procedure-set!
    record-type-hash-function			$record-type-hash-function
    record-type-hash-function-set!		$record-type-hash-function-set!
    record-type-method-retriever		$record-type-method-retriever
    record-type-method-retriever-set!		$record-type-method-retriever-set!

    record-type-compose-equality-predicate
    record-type-compose-comparison-procedure
    record-type-compose-hash-function

    ;; syntactic bindings for internal use only
    $make-record-type-descriptor		$make-record-type-descriptor-ex
    $make-record-constructor-descriptor
    $record-constructor				$rtd-subtype?
    $record-accessor/index			$record=
    $record-rtd
    internal-applicable-record-type-destructor
    internal-applicable-record-destructor
    record-type-method-call-late-binding-private
    $record-type-method-retriever-private)
  (import (except (vicare)
		  ;; bindings for (rnrs records procedural (6))
		  make-record-type-descriptor		make-record-constructor-descriptor
		  record-type-descriptor?		record-constructor-descriptor?
		  record-constructor			record-predicate
		  record-accessor			record-mutator
		  unsafe-record-accessor		unsafe-record-mutator
		  record-ref

		  ;; bindings for (rnrs records inspection (6))
		  record?				record-rtd
		  record-type-name			record-type-parent
		  record-type-uid			record-type-generative?
		  record-type-sealed?			record-type-opaque?
		  record-field-mutable?
		  record-type-field-names		record-type-uids-list

		  ;; extension utility functions, non-R6RS
		  rtd-subtype?				record-type-all-field-names
		  record=?				record!=?
		  record-reset!
		  record-printer			record-destructor
		  record
		  record-equality-predicate		record-comparison-procedure
		  record-hash-function
		  record-and-rtd?			record-object?
		  record-type-destructor-set!		record-type-destructor
		  record-type-printer-set!		record-type-printer
		  record-type-equality-predicate	record-type-equality-predicate-set!
		  record-type-comparison-procedure	record-type-comparison-procedure-set!
		  record-type-hash-function		record-type-hash-function-set!
		  record-type-method-retriever		record-type-method-retriever-set!

		  record-type-compose-equality-predicate
		  record-type-compose-comparison-procedure
		  record-type-compose-hash-function)
    (vicare system structs)
    (vicare system $fx)
    (vicare system $pairs)
    (vicare system $structs)
    (only (vicare system $records)
	  $record-guardian)
    (prefix (only (vicare system $records)
     		  $record-rtd)
     	    sys::)
    (vicare system $symbols)
    (vicare system $vectors)
    (only (vicare language-extensions syntaxes)
	  define-equality/sorting-predicate
	  define-inequality-predicate))


;;;; type definitions
;;
;;A Vicare's struct is a variable-length  block of memory referenced by machine words
;;tagged as vectors;  the first machine word  of the structure is a  reference to the
;;struct-type descriptor, which is itself a struct.  A block of memory is a struct if
;;and only if: a reference to it is tagged  as vector and its first word is tagged as
;;vector.
;;
;;   |----------------|----------| reference to struct
;;     heap pointer    vector tag
;;
;;   |----------------|----------| first word of struct
;;     heap pointer    vector tag    = reference to struct-type desc
;;                                   = reference to struct
;;
;;The struct-type  descriptor of the struct-type  descriptors is the return  value of
;;BASE-RTD.  The  graph of  references for  a struct  and its  type descriptor  is as
;;follows:
;;
;;       std ref
;;      |-------|---------------| struct instance
;;          |
;;   ---<---
;;  |
;;  |     std ref
;;   -->|-------|---------------| struct-type descriptor
;;          |
;;   ---<---
;;  |
;;  |     std ref
;;  +-->|-------|---------------| base struct-type descriptor
;;  |       |
;;   ---<---
;;
;;An R6RS record-type descriptor is a struct  instance of type <RTD>.  An R6RS record
;;instance is  a struct instance whose  first word references its  type descriptor: a
;;struct instance of type <RTD>.
;;
;;       RTD ref
;;      |-------|---------------| R6RS record instance
;;          |
;;   ---<---
;;  |
;;  |     std ref
;;   -->|-------|---------------| R6RS record-type descriptor
;;          |                      = struct instance of type <RTD>
;;   ---<---
;;  |
;;  |     std ref
;;  +-->|-------|---------------| <RTD> type descriptor
;;          |
;;   ---<---
;;  |
;;  |     std ref
;;  +-->|-------|---------------| base struct-type descriptor
;;  |       |
;;   ---<---
;;

(define-struct <rtd>
  ;;R6RS record type descriptor.
  ;;
  ;;NOTE The  first two fields  have the same  meaning of the  first two fields  of a
  ;;Vicare's struct-type descriptor and this is MANDATORY!!!
  ;;
  ;;Vicare's struct-type descriptor:
  ;;
  ;;   RTD  name size  other fields
  ;;  |----|----|----|------------
  ;;
  ;;R6RS record-type descriptor:
  ;;
  ;;   RTD  name size  other fields
  ;;  |----|----|----|------------
  ;;
  (name
		;0.   Symbol  representing  the   record  type  name,  for  debugging
		;purposes.
   total-fields-number
		;1.  Total number of fields, including the fields of the parents.
   fields-number
		;2.  This  subtype's number  of fields, excluding  the fields  of the
		;parents.
   first-field-index
		;3.  The index  of the first field  of this subtype in  the layout of
		;instances; it is the total number of fields of the parent type.  The
		;field  indexes  are defined  for  use  by the  primitive  operations
		;$STRUCT-REF and $STRUCT-SET!.
		;
		;The  layout of  a  record  instance of  type  Y  with the  following
		;definition:
		;
		;   (define-record-type X
		;     (fields a b c))
		;
		;   (define-record-type Y
		;     (parent X)
		;     (fields d e f))
		;
		;is:
		;
		;    rtd Y  a   b   c   d   e   f
		;   |-----|---|---|---|---|---|---|
		;           0   1   2   3   4   5
		;
		;so this field holds 0 in the <RTD>  of X and it holds 3 in the <RTD>
		;of Y.
   parent
		;4.   False  or  instance  of  <RTD>  structure;  it  is  the  parent
		;record-type descriptor.
   sealed?
		;5.  Boolean, true if this record type is sealed.
   opaque?
		;6.  Boolean, true if this record type is opaque.
   uid
		;7.   Scheme symbol  acting as  unique record  type identifier.   The
		;field "value" of the UID holds a reference to this <RTD>.
   uids-list
		;8.  A proper list of symbols  representing the type hierarcy of this
		;record-type.
   generative?
		;9.  True if this record type is generative.
   fields
		;10.  Scheme vector, normalised fields specification.
		;
		;It is a vector with an element  for each field defined by this <RTD>
		;(not the fields of the supertypes).   The elements have the order in
		;which  fields  where  given  to  MAKE-RECORD-TYPE-DESCRIPTOR.   Each
		;element is  a pair  whose car  is a  boolean, true  if the  field is
		;mutable, and  whose cdr  is a Scheme  symbol representing  the field
		;name.
		;
		;   (define-record-type X
		;      (fields (mutable a) b c))
		;
		;yields the following vector:
		;
		;   #((#t . a) (#f . b) (#f . c))
		;
   initialiser
		;11.  Function used to initialise  the fields of an already allocated
		;R6RS record.  This function is the same for every record-constructor
		;descriptor of this record-type.
   default-protocol
		;12.  False  or function.  When  a function:  it must be  the default
		;protocol function used when a record-constructor descriptor does not
		;have one.
   default-rcd
		;13.  False or an instance of <RCD>, a record-constructor descriptor.
		;When an  RCD: it  is used  whenever an  RCD for  a subtype  is built
		;without specifying a specific RCD.
   destructor
		;14.   False or  a function,  accepting one  argument, to  be invoked
		;whenever the record instance is garbage collected.
   printer
		;15.  A function, accepting two arguments, to be invoked whenever the
		;record instance is  printed.  The first argument is  the record, the
		;second argument is a textual output port.
   equality-predicate
		;16.  False or an equality predicate for this record-object type.
   comparison-procedure
		;17.  False or a comparison procedure for this record-object type.
   hash-function
		;18.  False or a hash function for this record-object type.
   method-retriever-public
		;19.  False  or the public  method-retriever: a function  accepting a
		;method   name  as   single   argument  and   returning  a   method's
		;implementation function as single return value.
   method-retriever-private
		;20.  False or  the private method-retriever: a  function accepting a
		;method  name as  single argument  and returning  a private  method's
		;implementation function as single return value.
   implemented-interfaces
		;21.  False  or a  vector of  pairs representing  the interface-types
		;implemented by this  record-type.  Each pair has: as car  the UID of
		;an interface-type; as cdr a method retriever procedure to be used by
		;the  interface method  callers.   The vector  includes the  parent's
		;vector.
   ))

#;(module ()
  (set-struct-type-printer! (type-descriptor <rtd>)
    (lambda (S port sub-printer)
      (define-inline (%display thing)
	(display thing port))
      (%display "#[rtd")
      (%display " name=")			(sub-printer (<rtd>-name S))
      (%display " total-fields-number=")	(sub-printer (<rtd>-total-fields-number S))
      (%display " this-fields-number=")		(sub-printer (<rtd>-fields-number S))
      (let ((prtd (<rtd>-parent S)))
	(if (<rtd>? prtd)
	    (begin
	      (%display " parent-name=")
	      (sub-printer (<rtd>-name prtd)))
	  (begin
	    (%display " parent=")
	    (sub-printer prtd))))
      (%display " sealed?=")			(sub-printer (<rtd>-sealed? S))
      (%display " opaque?=")			(sub-printer (<rtd>-opaque? S))
      (%display " fields=")			(sub-printer (<rtd>-fields  S))
      ;;We avoid printing the initialiser, default-protocol and default-rcd fields.
      (%display "]"))))

(define-struct <rcd>
  ;;R6RS record constructor descriptor.
  (rtd
		;A struct of type <RTD>, the associated record-type descriptor.
   parent-rcd
		;False  or a  struct  of type  <RCD>,  the parent  record-constructor
		;descriptor.
   maker
		;A function.   It is the function  to which the protocol  function is
		;applied to.   When there are no  parents: this function is  just the
		;initialiser of the record.  When there are parents: it is a function
		;calling  the  parent's  constructor   and  returning  this  record's
		;initialiser.
   constructor
		;A function.  It  is the result of applying the  protocol function to
		;the maker function.
   builder
		;A function.  It is the public constructor function, the one returned
		;by RECORD-CONSTRUCTOR.
   ))

#;(module ()
  (set-struct-type-printer! (type-descriptor <rcd>)
    (lambda (S port sub-printer)
      (define-inline (%display thing)
	(display thing port))
      (%display "#[rcd")
      (%display " rtd=")		(sub-printer (<rcd>-rtd S))
      (%display " prcd=")		(sub-printer (<rcd>-parent-rcd S))
      (%display " maker=")		(sub-printer (<rcd>-maker S))
      (%display " constructor=")	(sub-printer (<rcd>-constructor S))
      (%display " builder=")		(sub-printer (<rcd>-builder S))
      (%display "]"))))


;;;; record construction process
;;
;;Here we  want to discuss  what are: the record  initialiser, the record  maker, the
;;record builder, the record constructor.
;;
;;
;;Record initialiser
;;------------------
;;
;;Whenever we define a record type with no parent:
;;
;;   (define-record-type alpha
;;     (fields a b c)
;;     (protocol
;;      (lambda (alpha-initialiser)
;;        (lambda (a b c)
;;          (receive-and-return (R)
;;              (alpha-initialiser a b c)
;;            (assert (alpha? R)))))))
;;
;;the  "record initialiser"  is  the  procedure to  which  the  protocol function  is
;;applied; its  purpose is to store  the given values  in the record field  slots and
;;return the new record object.
;;
;;
;;Record maker
;;------------
;;
;;Whenever we define a record type with parent:
;;
;;   (define-record-type alpha
;;     (fields a b c)
;;     (protocol
;;      (lambda (alpha-initialiser)
;;        (lambda (a b c)
;;          (receive-and-return (R)
;;              (alpha-initialiser a b c)
;;            (assert (alpha? R)))))))
;;
;;   (define-record-type beta
;;     (parent alpha)
;;     (fields d e f)
;;     (protocol
;;      (lambda (alpha-maker)
;;        (lambda (a b c d e f)
;;          (receive-and-return (R)
;;              ((alpha-maker a b c) d e f)
;;            (assert (beta? R)))))))
;;
;;the "record maker" is the procedure to  which the protocol function is applied; its
;;purpose is to store the given values in the supertype record field slots and return
;;a function that store this type field values in their slots.
;;
;;Let's see another example with a double parent hierarchy:
;;
;;   (define-record-type alpha
;;     (fields a b c)
;;     (protocol
;;      (lambda (alpha-initialiser)
;;        (lambda (a b c)
;;          (receive-and-return (R)
;;              (alpha-initialiser a b c)
;;            (assert (alpha? R)))))))
;;
;;   (define-record-type beta
;;     (parent alpha)
;;     (fields d e f)
;;     (protocol
;;      (lambda (alpha-maker)
;;        (lambda (a b c d e f)
;;          (receive-and-return (R)
;;              ((alpha-maker a b c) d e f)
;;            (assert (beta? R)))))))
;;
;;   (define-record-type gamma
;;     (parent beta)
;;     (fields g h i)
;;     (protocol
;;      (lambda (beta-maker)
;;        (lambda (a b c d e f g h i)
;;          (receive-and-return (R)
;;              ((beta-maker a b c d e f) g h i)
;;           (assert (gamma? R)))))))
;;
;;
;;Record constructor
;;------------------
;;
;;The record constructor is the function  returned by the application of the protocol
;;function to the record maker or  record initialiser.  Under Vicare: the constructor
;;is generated at  record-type definition time; the protocol function  is called only
;;once.
;;


;;;; helpers

(define (record-fields-specification-vector? V)
  ;;Return true if  V is valid as vector  specifying the fields of a  record type.  A
  ;;fields vector looks like this:
  ;;
  ;;   #((mutable   <symbol-1>)
  ;;     (immutable <symbol-2>)
  ;;     (mutable   <symbol-3>))
  ;;
  ;;Remember that a Vicare vector has at most (greatest-fixnum) items.
  ;;
  (and (vector? V)
       (let ((V.len ($vector-length V)))
	 (let next-item ((i 0))
	   (or ($fx= i V.len)
	       (let ((item ($vector-ref V i)))
		 (and (pair? item)
		      ;;Check that the car is one of the symbols: mutable, immutable.
		      (let ((A ($car item)))
			(or (eq? A 'mutable)
			    (eq? A 'immutable)))
		      ;;Check that the cdr is a list holding a symbol.
		      (let ((D ($cdr item)))
			(and (pair? D)
			     (null? ($cdr D))
			     (symbol? ($car D))))
		      (next-item ($fxadd1 i)))))))))

(define (%normalise-fields-vector input-vector)
  ;;Parse  the  fields  specification  vector  and return  an  equivalent  vector  in
  ;;normalised  format; this  function  assumes that  INPUT-VECTOR  has already  been
  ;;validated as fields specification vector.  Example, the input vector:
  ;;
  ;;   #((mutable a) (immutable b))
  ;;
  ;;is transformed into:
  ;;
  ;;   #((#t . a) (#f . b))
  ;;
  ;;the symbols MUTABLE and IMMUTABLE are  respectively converted into true and false
  ;;booleans, lists are converted to pairs.
  ;;
  (let ((number-of-fields (vector-length input-vector)))
    (if (fxzero? number-of-fields)
	input-vector
      (let next-field ((normalised-vector ($make-clean-vector number-of-fields))
		       (i                 0))
	(if ($fx< i number-of-fields)
	    (let* ((item	($vector-ref input-vector i))
		   (mutability	($car item))
		   (name	($car ($cdr item))))
	      ($vector-set! normalised-vector i (cons (eq? mutability 'mutable) name))
	      (next-field normalised-vector ($fxadd1 i)))
	  normalised-vector)))))

(define (%field-name->absolute-field-index rtd field-name-sym)
  ;;Given a record-type descriptor and a symbol representing a field name: search the
  ;;hierarchy of RTDs for a field matching the selected name and return 2 values: its
  ;;absolute index; a boolean,  true if the field is mutable.   When a matching field
  ;;is not found: return false and false.
  ;;
  (let loop ((rtd  rtd)
	     (spec ($<rtd>-fields rtd))
	     (i    0))
    (cond (($fx= i ($vector-length spec))
	   (cond (($<rtd>-parent rtd)
		  => (lambda (prtd)
		       (%field-name->absolute-field-index prtd field-name-sym)))
		 (else
		  (values #f #f))))
	  ((eq? field-name-sym ($cdr ($vector-ref spec i)))
	   (values ($fx+ i ($<rtd>-first-field-index rtd))
		   ($car ($vector-ref spec i))))
	  (else
	   (loop rtd spec ($fxadd1 i))))))


;;;; argument validation helpers

(define-syntax-rule (record-type-descriptor? ?obj)
  (<rtd>? ?obj))

(define-syntax-rule (record-constructor-descriptor? ?obj)
  (<rcd>? ?obj))

(define-syntax-rule (record-type-name? ?obj)
  (symbol? ?obj))

(define-syntax-rule (non-opaque-record? ?obj)
  (record? ?obj))

(define-syntax-rule (field-index? ?obj)
  (non-negative-fixnum? ?obj))

(define (false/non-sealed-record-type-descriptor? obj)
  (or (not obj)
      (and (record-type-descriptor? obj)
	   (not (<rtd>-sealed? obj)))))

(define-syntax-rule (uid-specification? ?obj)
  (or (not ?obj)
      (symbol? ?obj)))

(define-syntax-rule (sealed-specification? ?obj)
  (boolean? ?obj))

(define-syntax-rule (opaque-specification? ?obj)
  (boolean? ?obj))

(define (false/record-constructor-descriptor? obj)
  (or (not obj)
      (record-constructor-descriptor? obj)))

(define (protocol-specification? obj)
  (or (not obj)
      (procedure? obj)))

;;; --------------------------------------------------------------------

(define-syntax (define-assertion stx)
  (syntax-case stx ()
    ((_ (?who ?arg0 ?arg ...) ?body0 ?body ...)
     #'(define-syntax (?who stx)
	 (syntax-case stx ()
	   ((_ ?arg0 ?arg ...)
	    (and (identifier? (syntax ?arg0))
		 (identifier? (syntax ?arg))
		 ...)
	    (syntax (begin ?body0 ?body ...)))
	   )))
    ))

(define-assertion (assert-absolute-field-index abs-index max-index rtd relative-field-index)
  (unless (and (fixnum? abs-index)
	       ($fx< abs-index max-index))
    (procedure-arguments-consistency-violation __who__
      (string-append "absolute field index " (number->string abs-index)
		     " out of range, expected non-negative fixnum less than " (number->string max-index))
      rtd relative-field-index)))

(define-assertion (assert-relative-index-of-mutable-field relative-field-index rtd)
  ;;To be called with RELATIVE-FIELD-INDEX being a  valid field index for RTD and RTD
  ;;being an R6RS record-type descriptor.
  ;;
  ;;We have  to remember that  the RTD structure holds  a normalised vector  of field
  ;;specifications.
  ;;
  (unless ($car ($vector-ref (<rtd>-fields rtd) relative-field-index))
    (procedure-arguments-consistency-violation __who__
      "selected record field is not mutable" relative-field-index rtd)))

(define-assertion (assert-rtd-and-parent-rcd rtd parent-rcd)
  (unless (or (not parent-rcd)
	      (eq? (<rtd>-parent rtd)
		   (<rcd>-rtd    parent-rcd)))
    (procedure-arguments-consistency-violation __who__
      "expected false or record-constructor descriptor associated to the \
       parent of the record-type descriptor"
      rtd parent-rcd)))


;;;; record instance inspection

(define (record-object? obj)
  ;;Return #t if OBJ is a record, else return #f.  Does not care about the opaqueness
  ;;of the record type.
  ;;
  (and ($struct? obj)
       (<rtd>? ($struct-std obj))))

(define (record? x)
  ;;Defined by R6RS.  Return #t if OBJ is a record and its record type is not opaque,
  ;;else return #f.
  ;;
  (and ($struct? x)
       (let ((rtd ($struct-std x)))
	 (and (<rtd>? rtd)
	      ($<rtd>-non-opaque? rtd)))))

(define ($<rtd>-non-opaque? rtd)
  (not ($<rtd>-opaque? rtd)))

(define* (record-rtd {x non-opaque-record?})
  ;;Defined by R6RS.  Return the record-type descriptor of the record X.
  ;;
  ($struct-std x))


;;;; record-type descriptor inspection

(let-syntax
    ((define-rtd-inspector (syntax-rules ()
			     ((_ ?procname ?accessor)
			      (define* (?procname {rtd record-type-descriptor?})
				(?accessor rtd))))))
  (define-rtd-inspector record-type-name		<rtd>-name)
  (define-rtd-inspector record-type-parent		<rtd>-parent)
  (define-rtd-inspector record-type-sealed?		<rtd>-sealed?)
  (define-rtd-inspector record-type-opaque?		<rtd>-opaque?)
  (define-rtd-inspector record-type-generative?		<rtd>-generative?)

  ;;Return false or the UID of RTD.   Notice that this library assumes that: there is
  ;;a difference between generative and non-generative record-type descriptors.  This
  ;;is what R6RS as to say about this function:
  ;;
  ;;	Return the UID of the record-type descriptor  RTD, or #f if it has none.  (An
  ;;	implementation may assign a  generated UID to a record type  even if the type
  ;;	is generative,  so the return  of a UID does  not necessarily imply  that the
  ;;	type is nongenerative.)
  ;;
  (define-rtd-inspector record-type-uid			<rtd>-uid)
  #| end of LET-SYNTAX |# )

(define* (record-type-field-names {rtd record-type-descriptor?})
  ;;Return a vector  holding one Scheme symbol  for each field of  RTD, not including
  ;;fields of the parents;  the order of the symbols is the same  of the order of the
  ;;fields in the RTD definition.
  ;;
  (let* ((fields-vector     ($<rtd>-fields rtd))
	 (number-of-fields  ($vector-length fields-vector)))
    (let next-field ((v ($make-clean-vector number-of-fields))
		     (i 0))
      (if ($fx= i number-of-fields)
	  v
	(begin
	  ($vector-set! v i ($cdr ($vector-ref fields-vector i)))
	  (next-field v ($fxadd1 i)))))))

(define* (record-field-mutable? {rtd record-type-descriptor?} {field-index field-index?})
  ;;Return true if field FIELD-INDEX of RTD is mutable.  Acts upon the fields of RTD,
  ;;not its supertypes.
  ;;
  (let* ((prtd			($<rtd>-parent rtd))
	 (absolute-field-index	(if prtd
				    (+ field-index ($<rtd>-total-fields-number prtd))
				  field-index)))
    (cond ((not (fixnum? absolute-field-index))
	   (procedure-arguments-consistency-violation __who__
	     "field index out of range" rtd field-index))
	  (($fx< absolute-field-index ($<rtd>-total-fields-number rtd))
	   ;;Remember  that the  RTD structure  holds  a normalised  vector of  field
	   ;;specifications.
	   ($car ($vector-ref ($<rtd>-fields rtd) field-index)))
	  (else
	   (procedure-arguments-consistency-violation __who__
	     "relative field index out of range for record type" field-index rtd)))))


(module RECORD-BUILDER
  (%the-builder record-being-built)
  ;;NOTE When accessing  the RTD we use  the unsafe ones "$<rtd>-" to  allow the boot
  ;;image  to  be initialised  correctly.   These  accessors have  no  infrastructure
  ;;checking  the  type of  values,  so  they can  be  used  when the  infrastructure
  ;;functions are not yet initialised.  (Marco Maggi; Fri Dec 4, 2015)

  (define record-being-built
    ;;Hold the record structure while it is built.
    ;;
    (make-parameter #f))

  (define (%the-builder rtd type-name constructor constructor-args)
    ;;The builder implementation.  Allocate a new record object then apply the client
    ;;constructor  to the  given arguments.   Check that  the value  returned by  the
    ;;constructor is of the correct type.
    ;;
    (let ((the-record (%alloc-clean-r6rs-record rtd)))
      (parametrise ((record-being-built the-record))
	(let ((client-record (apply constructor constructor-args))
	      (the-record    (record-being-built)))
	  (unless (eq? client-record the-record)
	    (unless (and ($struct? client-record)
			 (eq? ($struct-std client-record)
			      ($struct-std the-record)))
	      (assertion-violation type-name
		"while building new record, value returned by client record constructor is of invalid type"
		($struct-std the-record) client-record)))
	  client-record))))

  (define (%alloc-clean-r6rs-record rtd)
    ;;Allocate a new  R6RS record structure and  set all the fields to  void.  If the
    ;;record type has a destructor: register the record in the guardian.  RTD must be
    ;;an instance of <RTD>.
    ;;
    (let loop ((S ($make-clean-struct rtd))
	       (N ($<rtd>-total-fields-number rtd))
	       (i 0))
      (if ($fx= i N)
	  (cond (($<rtd>-destructor rtd)
		 => (lambda (destructor)
		      ($record-guardian S)))
		(else S))
	(begin
	  ($struct-set! S i (void))
	  (loop S N ($fxadd1 i))))))

  #| end of module |# )


(module RECORD-INITIALISERS
  (%make-record-initialiser)
  ;;NOTE When accessing  the RTD we use  the unsafe ones "$<rtd>-" to  allow the boot
  ;;image  to  be initialised  correctly.   These  accessors have  no  infrastructure
  ;;checking  the  type of  values,  so  they can  be  used  when the  infrastructure
  ;;functions are not yet initialised.  (Marco Maggi; Fri Dec 4, 2015)

  (define (%make-record-initialiser rtd)
    ;;Return  the initialiser  function for  an R6RS  record.  The  initialiser is  a
    ;;function that stores field values in a newly allocated record object.
    ;;
    (define fields-number ($<rtd>-fields-number rtd))
    (cond (($<rtd>-parent rtd)
	   => (lambda (prnt-rtd)
		(let ((start-index ($<rtd>-total-fields-number prnt-rtd)))
		  (lambda field-values
		    (%fill-record-fields (%record-being-built 'initialiser-with-parent)
					 rtd start-index fields-number fields-number
					 field-values field-values)))))
	  (else
	   (case fields-number
	     ((0)  %initialiser-without-parent-0)
	     ((1)  %initialiser-without-parent-1)
	     ((2)  %initialiser-without-parent-2)
	     ((3)  %initialiser-without-parent-3)
	     ((4)  %initialiser-without-parent-4)
	     ((5)  %initialiser-without-parent-5)
	     ((6)  %initialiser-without-parent-6)
	     ((7)  %initialiser-without-parent-7)
	     ((8)  %initialiser-without-parent-8)
	     ((9)  %initialiser-without-parent-9)
	     (else
	      (lambda field-values
		(%initialiser-without-parent+ rtd fields-number field-values)))))))

  (define (%record-being-built who)
    (module (record-being-built)
      (import RECORD-BUILDER))
    (or (record-being-built)
	;;This assertion may  happen if a protocol function calls  its maker argument
	;;directly, rather  than returning  a function  which in  turn will  call the
	;;maker.
	;;
	;;The correct way of doing things is:
	;;
	;;   (define-record-type X
	;;     (fields a b c)
	;;     (protocol
	;;       (lambda (make-record)
	;;         (lambda (a b c)
	;;           (make-record a b c)))))
	;;
	;;but if we do:
	;;
	;;   (define-record-type X
	;;     (fields a b c)
	;;     (protocol
	;;       (lambda (make-record)
	;;         (make-record 1 2 3))))
	;;
	;;this assertion happens.
	(assertion-violation who
	  "called record initialiser or maker without going through a proper constructor")))

  (define (%initialiser-without-parent-0)
    ;;Just return the record itself.
    ;;
    (%record-being-built '%initialiser-without-parent-0))

  (let-syntax
      ((define-initialiser-without-parent
	 (lambda (stx)
	   (define (%iota count)
	     ;;Return a list of exact integers from 0 included to COUNT excluded.
	     (let loop ((count	(fx- count 1))
			(ret	'()))
	       (if (negative? count)
		   ret
		 (loop (fx- count 1) (cons count ret)))))
	   (syntax-case stx ()
	     ((_ ?who ?argnum)
	      (let ((indices (%iota (syntax->datum #'?argnum))))
		(with-syntax (((INDEX ...) indices)
			      ((ARG   ...) (generate-temporaries indices)))
		  #'(define (?who ARG ...)
		      (receive-and-return (the-record)
			  (%record-being-built '?who)
			(assert the-record)
			($struct-set! the-record INDEX ARG)
			...)))))))))
    (define-initialiser-without-parent %initialiser-without-parent-1 1)
    (define-initialiser-without-parent %initialiser-without-parent-2 2)
    (define-initialiser-without-parent %initialiser-without-parent-3 3)
    (define-initialiser-without-parent %initialiser-without-parent-4 4)
    (define-initialiser-without-parent %initialiser-without-parent-5 5)
    (define-initialiser-without-parent %initialiser-without-parent-6 6)
    (define-initialiser-without-parent %initialiser-without-parent-7 7)
    (define-initialiser-without-parent %initialiser-without-parent-8 8)
    (define-initialiser-without-parent %initialiser-without-parent-9 9)
    #| end of LET-SYNTAX |# )

  (define (%initialiser-without-parent+ rtd fields-number field-values)
    (let ((the-record (%record-being-built '%initialiser-without-parent+)))
      (assert the-record)
      (%fill-record-fields the-record rtd 0 fields-number fields-number field-values field-values)))

  (define (%fill-record-fields the-record rtd field-index back-fields-counter fields-number
			       all-field-values field-values)
    ;;Recursive function.  When successful return THE-RECORD itself.
    ;;
    (define (%wrong-num-args)
      (assertion-violation ($<rtd>-name rtd)
	(string-append "wrong number of arguments to record initialiser, expected "
		       (number->string fields-number) " given " (number->string (length all-field-values)))
	rtd all-field-values))
    (if (null? field-values)
	(if (fxzero? back-fields-counter)
	    the-record
	  (%wrong-num-args))
      (if (fxzero? back-fields-counter)
	  (%wrong-num-args)
	(begin
	  ($struct-set! the-record field-index (car field-values))
	  (%fill-record-fields the-record rtd
			       (fxadd1 field-index) (fxsub1 back-fields-counter) fields-number
			       all-field-values (cdr field-values))))))

  #| end of module: RECORD-INITIALISERS |# )


(module RECORD-DEFAULT-PROTOCOL
  (%make-default-protocol)
  ;;NOTE When accessing  the RTD we use  the unsafe ones "$<rtd>-" to  allow the boot
  ;;image  to  be initialised  correctly.   These  accessors have  no  infrastructure
  ;;checking  the  type of  values,  so  they can  be  used  when the  infrastructure
  ;;functions are not yet initialised.  (Marco Maggi; Fri Dec 4, 2015)

  (define (%make-default-protocol rtd)
    ;;Build and return a default protocol function to be used whenever a a request to
    ;;build  an RCD  is  issued  without a  specific  protocol.   If available:  this
    ;;function  returns the  default  protocol stored  in RTD,  else  a new  protocol
    ;;function is built and cached in RTD.
    ;;
    (or ($<rtd>-default-protocol rtd)
	(receive-and-return (proto)
	    (if ($<rtd>-parent rtd)
		(%make-protocol/with-parent rtd)
	      (lambda (make-this-record)
		make-this-record))
	  ($set-<rtd>-default-protocol! rtd proto))))

  (define (%make-protocol/with-parent rtd)
    (define record-fields-number
      ($<rtd>-fields-number rtd))
    (lambda (make-parent-record) ;default protocol function
      (lambda given-field-values
	(define given-args-number
	  (length given-field-values))
	(if (fx<=? record-fields-number given-args-number)
	    (receive (parent-fields this-fields)
		(%split given-field-values ($fx- given-args-number record-fields-number))
	      (apply (apply make-parent-record parent-fields) this-fields))
	  (assertion-violation 'default-protocol-function
	    (string-append "not enough arguments for record constructor, expected "
			   (number->string record-fields-number)
			   " got " (number->string given-args-number))
	    rtd given-field-values)))))

  (define (%split all-field-values count)
    ;;Split the list ALL-FIELD-VALUES and return two values: a list holding the first
    ;;COUNT values from ALL-FIELD-VALUES, a list holding the rest.
    ;;
    (let next-value ((field-values	all-field-values)
		     (count		count))
      (unless (or ($fxzero? count)
		  (pair? field-values))
	(assertion-violation 'default-protocol-function
	  "insufficient arguments" field-values))
      (if ($fxzero? count)
	  (values '() field-values)
	(receive (tail rest)
	    (next-value ($cdr field-values) ($fxsub1 count))
	  (values (cons (car field-values) tail) rest)))))

  #| end of module |# )


(module (make-record-type-descriptor
	 make-record-type-descriptor-ex
	 $make-record-type-descriptor
	 $make-record-type-descriptor-ex)
  ;;NOTE When accessing  the RTD we use  the unsafe ones "$<rtd>-" to  allow the boot
  ;;image  to  be initialised  correctly.   These  accessors have  no  infrastructure
  ;;checking  the  type of  values,  so  they can  be  used  when the  infrastructure
  ;;functions are not yet initialised.  (Marco Maggi; Fri Dec 4, 2015)
  (module (%make-record-initialiser)
    (import RECORD-INITIALISERS))

  (define* (make-record-type-descriptor {name    record-type-name?}
  					{parent  false/non-sealed-record-type-descriptor?}
  					{uid     uid-specification?}
  					{sealed? sealed-specification?}
  					{opaque? opaque-specification?}
  					{fields  record-fields-specification-vector?})
    (let ((normalised-fields (%normalise-fields-vector fields)))
      ($make-record-type-descriptor name parent uid sealed? opaque? fields normalised-fields)))

  (define ($make-record-type-descriptor name parent uid sealed? opaque? fields normalised-fields)
    (let ((generative?	(if uid #f #t))
	  (uid		(or uid (gensym name))))
      ($make-record-type-descriptor-ex name parent uid generative? sealed? opaque? fields normalised-fields
				       #f ;destructor
				       #f ;printer
				       #f ;equality-predicate
				       #f ;comparison-procedure
				       #f ;hash-function
				       #f ;method-retriever
				       #f ;method-retriever-private
				       #f ;implemented-interfaces
				       )))

  (define* (make-record-type-descriptor-ex {name    record-type-name?}
					   {parent  false/non-sealed-record-type-descriptor?}
					   {uid     uid-specification?}
					   {sealed? sealed-specification?}
					   {opaque? opaque-specification?}
					   {fields  record-fields-specification-vector?}
					   {destructor (or not procedure?)}
					   {printer (or not procedure?)}
					   {equality-predicate (or not procedure?)}
					   {comparison-procedure (or not procedure?)}
					   {hash-function (or not procedure?)}
					   {method-retriever (or not procedure?)}
					   {method-retriever-private (or not procedure?)}
					   implemented-interfaces)
    (let ((normalised-fields	(%normalise-fields-vector fields))
	  (generative?		(if uid #f #t))
	  (uid			(or uid (gensym name))))
      ($make-record-type-descriptor-ex name parent uid generative? sealed? opaque? fields normalised-fields
				       destructor printer
				       equality-predicate comparison-procedure hash-function
				       method-retriever method-retriever-private
				       implemented-interfaces)))

  (define ($make-record-type-descriptor-ex name parent uid generative? sealed? opaque? fields normalised-fields
					   destructor printer
					   equality-predicate comparison-procedure hash-function
					   method-retriever method-retriever-private
					   implemented-interfaces)
    ;;Return a  record-type descriptor representing  a record type distinct  from all
    ;;the built-in types and other record types.
    ;;
    ;;See the R6RS document for details on the arguments.
    ;;
    ;;NOTE  This function  is called  while initialising  the boot  image.  For  this
    ;;reason it may be  necessary to use peculiar function calls  rather than what is
    ;;normally used when dealing  with record types; this is to  avoid crashes due to
    ;;some  core primitive's  loc gensyms  not  being initialised.   For example:  we
    ;;require  this  function to  have  the  NORMALISED-FIELDS argument  rather  than
    ;;building a normalised fields vector here.  (Marco Maggi; Fri Dec 4, 2015)
    ;;
    (receive-and-return (rtd)
	(if generative?
	    (%generate-rtd name parent uid generative? sealed? opaque? normalised-fields
			   destructor printer
			   equality-predicate comparison-procedure hash-function
			   method-retriever method-retriever-private
			   implemented-interfaces)
	  (%make-nongenerative-rtd name parent uid sealed? opaque? fields normalised-fields
				   destructor printer
				   equality-predicate comparison-procedure hash-function
				   method-retriever method-retriever-private
				   implemented-interfaces))
      ($set-<rtd>-initialiser! rtd (%make-record-initialiser rtd))))

  (define (%generate-rtd name parent-rtd uid generative? sealed? opaque? normalised-fields
			 destructor printer
			 equality-predicate comparison-procedure hash-function
			 method-retriever method-retriever-private
			 implemented-interfaces)
    ;;Build and return a new instance of RTD struct.
    ;;
    (let* ((fields-number		($vector-length normalised-fields))
	   (total-fields-number		(if parent-rtd
					    (fx+ fields-number ($<rtd>-total-fields-number parent-rtd))
					  fields-number))
	   (first-field-index		(if parent-rtd
					    ($<rtd>-total-fields-number parent-rtd)
					  0))
	   (opaque?			(or opaque? (and parent-rtd ($<rtd>-opaque? parent-rtd))))
	   (implemented-interfaces	(if implemented-interfaces
					    (if (and parent-rtd (<rtd>-implemented-interfaces parent-rtd))
						(vector-append implemented-interfaces (<rtd>-implemented-interfaces parent-rtd))
					      implemented-interfaces)
					  (if parent-rtd
					      (<rtd>-implemented-interfaces parent-rtd)
					    implemented-interfaces))))
      (receive-and-return (rtd)
	  ;;We  use  "$struct"  rather  than  "make-<rtd>"  to  avoid  crashes  while
	  ;;initialising the boot  image!!!  This way we separate  this function from
	  ;;whatever is the expansion of DEFINE-STRUCT.
	  (let ((uids-list (cons uid (if parent-rtd
					 (<rtd>-uids-list parent-rtd)
				       '(vicare:core-type:<record>
					 vicare:core-type:<struct>
					 vicare:core-type:<top>)))))
	    ($struct (type-descriptor <rtd>) name
		     total-fields-number fields-number first-field-index
		     parent-rtd sealed? opaque? uid uids-list generative? normalised-fields
		     #f ;initialiser
		     #f	;default-protocol
		     #f	;default-rcd
		     destructor printer
		     equality-predicate comparison-procedure hash-function
		     method-retriever method-retriever-private
		     implemented-interfaces))
	(%intern-nongenerative-rtd! uid rtd))))

  (define (%make-nongenerative-rtd name parent-rtd uid sealed? opaque? fields normalised-fields
				   destructor printer
				   equality-predicate comparison-procedure hash-function
				   method-retriever method-retriever-private
				   implemented-interfaces)
    ;;Build and  return a  new instance of  RTD or return  an already  generated (and
    ;;interned) RTD.  If the  specified UID holds an RTD in  its "value" field: check
    ;;that the arguments are compatible and return the interned RTD.
    ;;
    (cond ((%lookup-nongenerative-rtd uid)
	   => (lambda (rtd)
		(define (%error wrong-field)
		  (procedure-arguments-consistency-violation 'make-record-type-descriptor
		    (string-append
		     "requested access to non-generative record-type descriptor \
                      with " wrong-field " not equivalent to that in the interned RTD")
		    rtd `(,name ,parent-rtd ,uid ,sealed? ,opaque? ,fields)))
		;;Should this validation be omitted when we compile without arguments
		;;validation?  (Marco Maggi; Sun Mar 18, 2012)
		;;
		;;Notice that the requested NAME can be different from the one in the
		;;interned RTD.
		(if (eq? ($<rtd>-parent rtd) parent-rtd)
		    (if (boolean=? ($<rtd>-sealed? rtd) sealed?)
			(if (boolean=? ($<rtd>-opaque? rtd) opaque?)
			    (if (equal? ($<rtd>-fields  rtd) normalised-fields)
				;;Return the interned RTD.
				rtd
			      (%error "fields"))
			  (%error "opaque"))
		      (%error "sealed"))
		  (%error "parent"))))
	  (else
	   ;;Build a new RTD and intern it.
	   (%generate-rtd name parent-rtd uid #f sealed? opaque? normalised-fields
			  destructor printer
			  equality-predicate comparison-procedure hash-function
			  method-retriever method-retriever-private
			  implemented-interfaces))))

  (define-syntax-rule (%intern-nongenerative-rtd! ?uid ?rtd)
    ($set-symbol-value! ?uid ?rtd))

  (define-syntax-rule (%lookup-nongenerative-rtd ?uid)
    (let ((rtd ($symbol-value ?uid)))
      (if ($unbound-object? rtd)
	  #f
	rtd)))

  #| end of module: MAKE-RECORD-TYPE-DESCRIPTOR |# )


(module (make-record-constructor-descriptor
	 $make-record-constructor-descriptor)
  ;;NOTE When accessing  the RTD we use  the unsafe ones "$<rtd>-" to  allow the boot
  ;;image  to  be initialised  correctly.   These  accessors have  no  infrastructure
  ;;checking  the  type of  values,  so  they can  be  used  when the  infrastructure
  ;;functions are not yet initialised.  (Marco Maggi; Fri Dec 4, 2015)
  (module (record-being-built %the-builder %make-default-protocol)
    (import RECORD-INITIALISERS RECORD-BUILDER RECORD-DEFAULT-PROTOCOL))

  (define-syntax __module_who__
    (identifier-syntax 'make-record-constructor-descriptor))

  (define* (make-record-constructor-descriptor {rtd record-type-descriptor?}
					       {parent-rcd false/record-constructor-descriptor?}
					       {protocol protocol-specification?})
    ;;Return a  record-constructor descriptor specifying a  record constructor, which
    ;;can be used to construct record values  of the type specified by RTD, and which
    ;;can be obtained via RECORD-CONSTRUCTOR.
    ;;
    ;;PARENT-RCD must be  false or a record-constructor descriptor for  the parent of
    ;;RTD; when  false: a  default record-constructor descriptor  is built,  used and
    ;;cached in the RTD struct.
    ;;
    ;;PROTOCOL must be false or a function;  when false: a default protocol is built,
    ;;used and cached in the RTD struct.
    ;;
    (assert-rtd-and-parent-rcd rtd parent-rcd)
    ($make-record-constructor-descriptor rtd parent-rcd protocol))

  (define ($make-record-constructor-descriptor rtd parent-rcd protocol)
    (let* ((parent-rtd     ($<rtd>-parent rtd))
	   ;;If there is a parent RTD, but not a specific parent RCD: make use of the
	   ;;default RCD for the parent RTD.
	   (parent-rcd     (and parent-rtd
				(or parent-rcd
				    (%make-default-constructor-descriptor parent-rtd))))
	   (protocol-func  (or protocol (%make-default-protocol rtd)))
	   (maker-func     (let ((initialiser ($<rtd>-initialiser rtd)))
			     (if parent-rtd
				 (let ((parent-constructor ($<rcd>-constructor parent-rcd)))
				   (lambda parent-constructor-args
				     (%the-maker initialiser parent-constructor parent-constructor-args)))
			       initialiser)))
	   (constructor    (protocol-func maker-func)))
      (unless (procedure? constructor)
	(expression-return-value-violation __module_who__
	  "expected procedure as return value of R6RS record protocol function"
	  1 constructor))
      (let ((builder (let ((name ($<rtd>-name rtd)))
		       (lambda constructor-args
			 (%the-builder rtd name constructor constructor-args)))))
	($struct (type-descriptor <rcd>) rtd parent-rcd maker-func constructor builder))))

  (define (%make-default-constructor-descriptor rtd)
    ;;Similar  to  MAKE-RECORD-CONSTRUCTOR-DESCRIPTOR  but   makes  use  of  all  the
    ;;defaults.  If available:  this function returns the default RCD  stored in RTD,
    ;;else a new RCD is built and cached in RTD.
    ;;
    (or ($<rtd>-default-rcd rtd)
	(let* ((parent-rtd	($<rtd>-parent rtd))
	       (parent-rcd	(and parent-rtd
				     (%make-default-constructor-descriptor rtd)))
	       (protocol	(%make-default-protocol rtd))
	       (initialiser	($<rtd>-initialiser rtd))
	       (maker		(if parent-rtd
				    (let ((parent-constructor ($<rcd>-constructor parent-rcd)))
				      (lambda parent-constructor-args
					(%the-maker initialiser parent-constructor
						    parent-constructor-args)))
				  initialiser))
	       (constructor	(protocol maker))
	       (builder		(lambda constructor-args
				  (%the-builder rtd ($<rtd>-name rtd) constructor constructor-args)))
	       (default-rcd	($struct (type-descriptor <rcd>) rtd parent-rcd maker constructor builder)))
	  ($set-<rtd>-default-rcd! rtd default-rcd)
	  default-rcd)))

  (define (%the-maker initialiser parent-constructor parent-constructor-args)
    ;;The maker function implementation.  Call the parent constructor then return the
    ;;initialiser for  this record  type.  Check that  the parent  construtor returns
    ;;either the record being built itself, or a record instance of the correct RTD.
    ;;
    ;;Notice that, with  this implementation, the constructor can call  the maker any
    ;;number of  times and  nothing bad  happens on  this side.   If the  client code
    ;;messes up its state it is its own business.
    ;;
    (let ((client-record (apply parent-constructor parent-constructor-args))
	  (the-record    (record-being-built)))
      (unless (eq? client-record the-record)
	(unless (and ($struct? client-record)
		     (eq? ($struct-std client-record)
			  ($struct-std the-record)))
	  (assertion-violation 'a-record-maker
	    "value returned by client record constructor is of invalid type"
	    ($struct-std the-record) client-record))
	;;Replace the  record being built  with the  instance returned by  the parent
	;;constructor.
	(record-being-built client-record))
      initialiser))

  #| end of module |# )


;;;; record-type descriptor: procedure generation

(define* (record-constructor {rcd record-constructor-descriptor?})
  ($<rcd>-builder rcd))

(define ($record-constructor rtd)
  ;;Remember that "$<rcd>-builder" is a syntax, so it cannot be exported by "(psyntax
  ;;system $all)".  This wrapper function can be exported.
  ;;
  ($<rcd>-builder rtd))

(define* (record-predicate {rtd record-type-descriptor?})
  ;;Return a function being the predicate for RTD.
  ;;
  (lambda (record)
    (and ($struct? record)
	 ($record-and-rtd? record rtd))))


;;;; record accessors and mutators
;;
;;We have to remember that, given the definitions:
;;
;; (define-record-type <alpha>
;;   (fields a b c))
;;
;; (define-record-type <beta>
;;   (parent <alpha>)
;;   (fields d e f))
;;
;; (define-record-type <gamma>
;;   (parent <beta>)
;;   (fields g h i))
;;
;;the layout of a record of type <GAMMA> is something like:
;;
;;  [RTD-<gamma>, a, b, c, d, e, f, g, h, i]
;;
;;               |0, 1, 2|			relative offsets of <ALPHA>
;;                        |0, 1, 2|		relative offsets of <BETA>
;;                                 |0, 1, 2|	relative offsets of <GAMMA>
;;               |0, 1, 2, 3, 4, 5, 6, 7, 8|	absolute offsets of <GAMMA>
;;

(define* (record-ref {reco record-object?} {idx non-negative-fixnum?})
  ($record-ref reco idx))

(define* ($record-ref reco idx)
  (let ((max ($<rtd>-total-fields-number ($struct-std reco))))
    (if ($fx< idx max)
	($struct-ref reco idx)
      (procedure-arguments-consistency-violation __who__
	"field index out of range for record" idx max))))

(define ($record-rtd reco)
  (sys::$record-rtd reco))

;;; --------------------------------------------------------------------

(module (record-accessor
	 record-mutator
	 unsafe-record-accessor
	 unsafe-record-mutator)

  (case-define* record-accessor
    ;;Return a function being the safe accessor for field INDEX/NAME of RTD.
    ;;
    (({rtd record-type-descriptor?} index/name)
     (%record-actor __who__ rtd index/name 'a-record-accessor #t #t))
    (({rtd record-type-descriptor?} index/name accessor-who)
     (%record-actor __who__ rtd index/name accessor-who #t #t)))

  (case-define* unsafe-record-accessor
    ;;Return a function being the unsafe accessor for field INDEX/NAME of RTD.
    ;;
    (({rtd record-type-descriptor?} index/name)
     (%record-actor __who__ rtd index/name 'a-record-accessor #t #f))
    (({rtd record-type-descriptor?} index/name accessor-who)
     (%record-actor __who__ rtd index/name accessor-who #t #f)))

  (case-define* record-mutator
    ;;Return a function being the safe mutator for field INDEX/NAME of RTD.
    ;;
    (({rtd record-type-descriptor?} index/name)
     (%record-actor __who__ rtd index/name 'a-record-mutator #f #t))
    (({rtd record-type-descriptor?} index/name mutator-who)
     (%record-actor __who__ rtd index/name mutator-who #f #t)))

  (case-define* unsafe-record-mutator
    ;;Return a function being the unsafe mutator for field INDEX/NAME of RTD.
    ;;
    (({rtd record-type-descriptor?} index/name)
     (%record-actor __who__ rtd index/name 'a-record-mutator #f #f))
    (({rtd record-type-descriptor?} index/name mutator-who)
     (%record-actor __who__ rtd index/name mutator-who #f #f)))

  (define (%record-actor who rtd index/name actor-who accessor? safe?)
    ;;Build and return a closure acting as field accessor or mutator for R6RS records
    ;;whose type is described by RTD.
    ;;
    ;;INDEX/NAME  must be  one among:  a non-negative  fixnum representing  the field
    ;;relative index among the fields described by RTD (not the supertypes of RTD); a
    ;;symbol representing the name of the field.
    ;;
    ;;ACCESSOR? must be true if a field  accessor must be generated; it must be false
    ;;if a field muator must be generated.
    ;;
    ;;SAFE? must be true if a safe accessor  or mutator must be generated; it must be
    ;;false if an  unsafe accessor or mutator must be  generated.  Safe accessors and
    ;;mutators do validate their arguments (so they are slower); unsafe accessors and
    ;;mutators do not validate their arguments (so they are faster).
    ;;
    (fluid-let-syntax
	((__who__ (identifier-syntax who)))
      (receive (abs-index mutable?)
	  (cond ((non-negative-fixnum? index/name)
		 (let* ((relative-field-index    index/name)
			(total-number-of-fields  ($<rtd>-total-fields-number rtd))
			(abs-index               (+ relative-field-index ($<rtd>-first-field-index rtd))))
		   (assert-absolute-field-index abs-index total-number-of-fields rtd relative-field-index)
		   (values abs-index ($car ($vector-ref ($<rtd>-fields rtd) relative-field-index)))))

		((symbol? index/name)
		 (receive (abs-index mutable?)
		     (%field-name->absolute-field-index rtd index/name)
		   (if abs-index
		       (values abs-index mutable?)
		     (procedure-arguments-consistency-violation who
		       "unknown field name for record-type descriptor"
		       rtd index/name))))

		(else
		 (procedure-argument-violation who
		   "expected field index fixnum or symbol name as argument"
		   index/name)))
	(cond (accessor?
	       (if safe?
		   (lambda (obj)
		     ;;We must verify that OBJ  is actually an R6RS record
		     ;;instance of RTD or one of its subtypes.
		     ;;
		     (unless (record-object? obj)
		       (procedure-argument-violation actor-who
			 "expected R6RS record as argument to field accessor" obj))
		     (unless (record-and-rtd? obj rtd)
		       (procedure-arguments-consistency-violation actor-who
			 "R6RS record is not an instance of the expected record-type descriptor"
			 obj rtd))
		     ($struct-ref obj abs-index))
		 (lambda (obj)
		   ($struct-ref obj abs-index))))

	      (mutable?
	       (if safe?
		   (lambda (obj new-value)
		     ;;We must verify that OBJ  is actually an R6RS record
		     ;;instance of RTD or one of its subtypes.
		     ;;
		     (unless (record-object? obj)
		       (procedure-argument-violation actor-who
			 "expected R6RS record as argument to field mutator" obj))
		     (unless (record-and-rtd? obj rtd)
		       (procedure-arguments-consistency-violation actor-who
			 "R6RS record is not an instance of the expected record-type descriptor"
			 obj rtd))
		     ($struct-set! obj abs-index new-value))
		 (lambda (obj new-value)
		   ($struct-set! obj abs-index new-value))))

	      (else
	       ;;If we  are here the  caller has requested a  mutator, but
	       ;;the field is immutable.
	       (procedure-arguments-consistency-violation who
		 "requested mutator for immutable field"
		 rtd index/name))))))

  #| end of module |# )

(define ($record-accessor/index rtd relative-field-index accessor-who)
  (let ((absolute-field-index (fx+ relative-field-index ($<rtd>-first-field-index rtd))))
    (lambda (obj)
      ;;We must verify that OBJ is actually an  R6RS record instance of RTD or one of
      ;;its subtypes.
      ;;
      (unless (record-object? obj)
	(procedure-argument-violation accessor-who
	  "expected R6RS record as argument to field accessor" obj))
      (unless (record-and-rtd? obj rtd)
	(procedure-arguments-consistency-violation accessor-who
	  "R6RS record is not an instance of the expected record-type descriptor"
	  obj rtd))
      ($struct-ref obj absolute-field-index))))


;;;; non-R6RS extensions: miscellaneous functions

(define (record-and-rtd? record rtd)
  ;;Vicare extension.  Return  #t if RECORD is  a record instance of RTD  or a record
  ;;instance of a subtype of RTD.
  (and ($struct? record)
       (record-type-descriptor? rtd)
       ($record-and-rtd? record rtd)))

(define ($record-and-rtd? record rtd)
  ;;We must  verify that  RECORD is  actually a record  instance of  RTD or  a record
  ;;instance of  a subtype of  RTD.
  ;;
  ;;The argument  RECORD must  be a  struct instance.   The argument  RTD can  be any
  ;;object, but it should be a record-type descriptor.
  ;;
  (let ((rtd^ ($struct-std record)))
    (or (eq? rtd rtd^)
	(and (<rtd>? rtd^)
	     (let upper-parent ((prtd^ ($<rtd>-parent rtd^)))
	       (and prtd^
		    (or (eq? rtd prtd^)
			(upper-parent ($<rtd>-parent prtd^)))))))))

;;; --------------------------------------------------------------------

(define* (rtd-subtype? {rtd record-type-descriptor?} {prtd record-type-descriptor?})
  ;;Return true if PRTD is a parent of RTD or they are equal.
  ;;
  ($rtd-subtype? rtd prtd))

(define ($rtd-subtype? rtd prtd)
  (or (eq? rtd prtd)
      (let upper-parent ((prtd^ ($<rtd>-parent rtd)))
	(and prtd^
	     (or (eq? prtd^ prtd)
		 (upper-parent ($<rtd>-parent prtd^)))))))

(define* (record-type-all-field-names {rtd record-type-descriptor?})
  ;;Return a vector holding one Scheme symbol for each field of RTD, including fields
  ;;of the parents; the  order of the symbols is the same of  the order of the fields
  ;;in the RTD definition.
  ;;
  (apply vector-append
	 ;;Typically  the hierarchy  of  RTDs is  "short": 2,  3,  4 supertypes.   So
	 ;;reversing the list is not a big problem.
	 (reverse (let recur ((rtd rtd))
		    (cond ((record-type-parent rtd)
			   => (lambda (prtd)
				(cons (record-type-field-names rtd)
				      (recur prtd))))
			  (else
			   (list (record-type-field-names rtd))))))))

(define-equality/sorting-predicate record=?	$record=	record-object?)
(define-inequality-predicate       record!=?	$record!=	record-object?)

(define ($record= obj1 obj2)
  ;;Return true if OBJ1  and OBJ2 are two R6RS records having the  same RTD and equal
  ;;field values according to EQUAL?.
  ;;
  (let ((rtd1 ($struct-std obj1)))
    (and (eq? rtd1 ($struct-std obj2))
	 (let ((len ($vector-length ($<rtd>-fields rtd1))))
	   (let loop ((i 0))
	     (or ($fx= i len)
		 (and (equal? ($struct-ref obj1 i)
			      ($struct-ref obj2 i))
		      (loop ($fxadd1 i)))))))))

(define ($record!= reco1 reco2)
  (not ($record= reco1 reco2)))

(define* (record-reset! {x non-opaque-record?})
  ;;Reset to #f all the fields of a record.
  ;;
  ;;Remember that the  first 2 fields of an R6RS  record type descriptor
  ;;have the same meaning of the first  2 fields of a Vicare struct type
  ;;descriptor.
  (let ((len ($struct-ref ($struct-std x) 1)))
    (do ((i 0 ($fxadd1 i)))
	(($fx= i len)
	 (values))
      ($struct-set! x i (void)))))

;;;

(define* (record-printer {x record-object?})
  ($<rtd>-printer ($struct-std x)))

(define ($record-printer x)
  ($<rtd>-printer ($struct-std x)))


;;;; non-R6RS extensions: record destructor

(define* (record-type-destructor-set! {rtd record-type-descriptor?} {func procedure?})
  ;;Store a function as destructor in a R6RS record-type descriptor.  Return the void
  ;;object.
  ;;
  ($set-<rtd>-destructor! rtd func))

(define ($record-type-destructor-set! rtd func)
  ;;Store a function as destructor in a R6RS record-type descriptor.  Return the void
  ;;object.
  ;;
  ($set-<rtd>-destructor! rtd func))

;;;

(define* (record-type-destructor {rtd record-type-descriptor?})
  ;;Return the value of the destructor field in RTD: #f or a function.
  ;;
  ($<rtd>-destructor rtd))

(define ($record-type-destructor rtd)
  ;;Remember  that "$<rcd>-destructor"  is  a syntax,  so it  cannot  be exported  by
  ;;"(psyntax system $all)".  This wrapper function can be exported.
  ;;
  ($<rtd>-destructor rtd))

;;; --------------------------------------------------------------------

(define* (record-destructor {rtd record-object?})
  ($<rtd>-destructor ($struct-std rtd)))

(define ($record-destructor rtd)
  ($<rtd>-destructor ($struct-std rtd)))

;;; --------------------------------------------------------------------

(define (internal-applicable-record-type-destructor rtd)
  ;;This private primitive is used by the DEFINE-RECORD-TYPE syntax.  If a destructor
  ;;is set in  RTD: return it; otherwise  return a function that  does nothing.  This
  ;;way we can use DELETE on both  records having a destructor and records not having
  ;;a destructor.
  ;;
  (or ($<rtd>-destructor rtd)
      (lambda (x) (void))))

(define (internal-applicable-record-destructor record)
  ;;This private primitive is used by  the INTERNAL-DELETE function.  If a destructor
  ;;is set  in the RTD of  RECORD: return it;  otherwise return a function  that does
  ;;nothing.  This way we can use INTERNAL-DELETE on both records having a destructor
  ;;and records not having a destructor.
  ;;
  ;;Notice that this works also on opaque records.
  ;;
  (or ($<rtd>-destructor ($struct-std record))
      (lambda (x) (void))))


;;;; non-R6RS extensions: record printer

(define* (record-type-printer-set! {rtd record-type-descriptor?} {func (or not procedure?)})
  ;;Store false  or a function as  printer in a R6RS  record-type descriptor.  Return
  ;;the void object.
  ;;
  ($set-<rtd>-printer! rtd func))

(define ($record-type-printer-set! rtd func)
  ;;Store false  or a function as  printer in a R6RS  record-type descriptor.  Return
  ;;the void object.
  ;;
  ($set-<rtd>-printer! rtd func))

(define* (record-type-printer {rtd record-type-descriptor?})
  ;;Return false or the printer function from RTD.
  ;;
  ($<rtd>-printer rtd))

(define ($record-type-printer rtd)
  ;;Return false or the printer function from RTD.
  ;;
  ($<rtd>-printer rtd))


;;;; non-R6RS extensions: equality predicate

(define* (record-type-equality-predicate-set! {rtd record-type-descriptor?} {func (or not procedure?)})
  ;;Store false or a function as equality predicate in a R6RS record-type descriptor.
  ;;Return the void object.
  ;;
  ($set-<rtd>-equality-predicate! rtd func))

(define ($record-type-equality-predicate-set! rtd func)
  ;;Store false or a function as equality predicate in a R6RS record-type descriptor.
  ;;Return the void object.
  ;;
  ($set-<rtd>-equality-predicate! rtd func))

(define* (record-type-equality-predicate {rtd record-type-descriptor?})
  ;;Return false or the equality predicate function from RTD.
  ;;
  ($<rtd>-equality-predicate rtd))

(define ($record-type-equality-predicate rtd)
  ;;Return false or the equality predicate function from RTD.
  ;;
  ($<rtd>-equality-predicate rtd))

;;;

(define* (record-type-compose-equality-predicate {rtd record-type-descriptor?} {equal-proto procedure?})
  ;;If  the record-type  RTD  has  a parent:  apply  the equality-predicate  protocol
  ;;function EQUAL-PROTO  to the equality  predicate of the  parent (or false  if the
  ;;parent has no equality predicate) and store the resulting procedure in RTD.
  ;;
  ;;If  the record-type  RTD  has  no parent:  call  the equality-predicate  protocol
  ;;function EQUAL-PROTO as a thunk and store the resulting procedure in RTD.
  ;;
  ;;Return the equality predicate itself.
  ;;
  (receive-and-return (equal-pred)
      (cond ((record-type-parent rtd)
	     => (lambda (prtd)
		  (equal-proto (record-type-equality-predicate prtd))))
	    (else
	     (equal-proto)))
    (if (procedure? equal-pred)
	(record-type-equality-predicate-set! rtd equal-pred)
      (assertion-violation __who__
	"expected closure object from evaluation of equality-predicate protocol function"
	rtd equal-pred))))

;;; --------------------------------------------------------------------

(define* (record-equality-predicate {reco record-object?})
  ;;Return false or the equality predicate from the record-type descriptor of RECO.
  ;;
  ($<rtd>-equality-predicate ($struct-std reco)))

(define ($record-equality-predicate reco)
  ;;Return false or the equality predicate from the record-type descriptor of RECO.
  ;;
  ($<rtd>-equality-predicate ($struct-std reco)))


;;;; non-R6RS extensions: comparison procedure

(define* (record-type-comparison-procedure-set! {rtd record-type-descriptor?} {func (or not procedure?)})
  ;;Store  false  or  a  function  as comparison  procedure  in  a  R6RS  record-type
  ;;descriptor.  Return the void object.
  ;;
  ($set-<rtd>-comparison-procedure! rtd func))

(define ($record-type-comparison-procedure-set! rtd func)
  ;;Store  false  or  a  function  as comparison  procedure  in  a  R6RS  record-type
  ;;descriptor.  Return the void object.
  ;;
  ($set-<rtd>-comparison-procedure! rtd func))

(define* (record-type-comparison-procedure {rtd record-type-descriptor?})
  ;;Return false or the comparison procedure function from RTD.
  ;;
  ($<rtd>-comparison-procedure rtd))

(define ($record-type-comparison-procedure rtd)
  ;;Return false or the comparison procedure function from RTD.
  ;;
  ($<rtd>-comparison-procedure rtd))

;;;

(define* (record-type-compose-comparison-procedure {rtd record-type-descriptor?} {compar-proto procedure?})
  ;;If  the record-type  RTD has  a parent:  apply the  comparison-procedure protocol
  ;;function COMPAR-PROTO to the comparison procedure  of the parent (or false if the
  ;;parent has no comparison procedure) and store the resulting procedure in RTD.
  ;;
  ;;If  the record-type  RTD has  no parent:  call the  comparison-procedure protocol
  ;;function COMPAR-PROTO as a thunk and store the resulting procedure in RTD.
  ;;
  ;;Return the comparison procedure itself.
  ;;
  (receive-and-return (compar-proc)
      (cond ((record-type-parent rtd)
	     => (lambda (prtd)
		  (compar-proto (record-type-comparison-procedure prtd))))
	    (else
	     (compar-proto)))
    (if (procedure? compar-proc)
	(record-type-comparison-procedure-set! rtd compar-proc)
      (assertion-violation __who__
	"expected closure object from evaluation of comparison-procedure protocol function"
	rtd compar-proc))))

;;; --------------------------------------------------------------------

(define* (record-comparison-procedure {reco record-object?})
  ;;Return false or the comparison procedure from the record-type descriptor of RECO.
  ;;
  ($<rtd>-comparison-procedure ($struct-std reco)))

(define ($record-comparison-procedure reco)
  ;;Return false or the comparison procedure from the record-type descriptor of RECO.
  ;;
  ($<rtd>-comparison-procedure ($struct-std reco)))


;;;; non-R6RS extensions: hash function

(define* (record-type-hash-function-set! {rtd record-type-descriptor?} {func (or not procedure?)})
  ;;Store false  or a  function as  hash function in  a R6RS  record-type descriptor.
  ;;Return the void value.
  ;;
  ($set-<rtd>-hash-function! rtd func))

(define ($record-type-hash-function-set! rtd func)
  ;;Store false  or a  function as  hash function in  a R6RS  record-type descriptor.
  ;;Return the void object.
  ;;
  ($set-<rtd>-hash-function! rtd func))

(define* (record-type-hash-function {rtd record-type-descriptor?})
  ;;Return false or the hash function function from RTD.
  ;;
  ($<rtd>-hash-function rtd))

(define ($record-type-hash-function rtd)
  ;;Return false or the hash function function from RTD.
  ;;
  ($<rtd>-hash-function rtd))

;;;

(define* (record-type-compose-hash-function {rtd record-type-descriptor?} {hash-proto procedure?})
  ;;If the  record-type RTD has a  parent: apply the hash-function  protocol function
  ;;HASH-PROTO to the hash function of the parent (or false if the parent has no hash
  ;;function) and store the resulting procedure in RTD.
  ;;
  ;;If the  record-type RTD has no  parent: call the hash-function  protocol function
  ;;HASH-PROTO as a thunk and store the resulting procedure in RTD.
  ;;
  ;;Return the hash function itself.
  ;;
  (receive-and-return (hash-func)
      (cond ((record-type-parent rtd)
	     => (lambda (prtd)
		  (hash-proto (record-type-hash-function prtd))))
	    (else
	     (hash-proto)))
    (if (procedure? hash-func)
	(record-type-hash-function-set! rtd hash-func)
      (assertion-violation __who__
	"expected closure object from evaluation of hash-function protocol function"
	rtd hash-func))))

;;; --------------------------------------------------------------------

(define* (record-hash-function {reco record-object?})
  ;;Return false or the hash function from the record-type descriptor of RECO.
  ;;
  ($<rtd>-hash-function ($struct-std reco)))

(define ($record-hash-function reco)
  ;;Return false or the hash function from the record-type descriptor of RECO.
  ;;
  ($<rtd>-hash-function ($struct-std reco)))


;;;; non-R6RS extensions: method retriever

(define* (record-type-method-retriever-set! {rtd record-type-descriptor?} {func (or false? procedure?)})
  ;;Store false  or a function  as method retriever  procedure in a  R6RS record-type
  ;;descriptor.  Return the void object.
  ;;
  ($set-<rtd>-method-retriever-public! rtd func))

(define ($record-type-method-retriever-set! rtd func)
  ;;Store false  or a function  as method retriever  procedure in a  R6RS record-type
  ;;descriptor.  Return the void object.
  ;;
  ($set-<rtd>-method-retriever-public! rtd func))

(define* (record-type-method-retriever {rtd record-type-descriptor?})
  ;;Return false or the method retriever procedure from RTD.
  ;;
  ($<rtd>-method-retriever-public rtd))

(define ($record-type-method-retriever rtd)
  ;;Return false or the method retriever procedure from RTD.
  ;;
  ($<rtd>-method-retriever-public rtd))

(define ($record-type-method-retriever-private rtd)
  ;;Return false or the private method retriever procedure from RTD.
  ;;
  ($<rtd>-method-retriever-private rtd))

;;; --------------------------------------------------------------------

(define* (record-method-retriever {reco record-object?})
  ;;Return false or the method retriever procedure from the record-type descriptor of
  ;;RECO.
  ;;
  ($<rtd>-method-retriever-public ($struct-std reco)))

(define ($record-method-retriever reco)
  ;;Return false or the method retriever procedure from the record-type descriptor of
  ;;RECO.
  ;;
  ($<rtd>-method-retriever-public ($struct-std reco)))

;;; --------------------------------------------------------------------

(define* (record-type-method-call-late-binding-private method-name.sym subject . args)
  ;;This function is used for late binding  of virtual methods when access to private
  ;;and protected methods is needed.
  ;;
  ;;This function is for internal use only.
  ;;
  (cond ((($record-type-method-retriever-private ($struct-std subject)) method-name.sym)
	 => (lambda (proc)
	      (apply proc subject args)))
	(else
	 (raise
	  (condition (make-method-late-binding-error)
		     (make-who-condition __who__)
		     (make-message-condition "record-type has no matching method")
		     (make-irritants-condition (list method-name.sym subject args)))))))



;;;; done

;; #!vicare
;; (define dummy
;;   (foreign-call "ikrt_print_emergency" #ve(ascii "ikarus.records.procedural end")))

#| end of library |# )

;;; end of file
