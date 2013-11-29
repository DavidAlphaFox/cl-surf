(defpackage :com.cvberry.util
  (:use :common-lisp)
  (:export :break-transparent
	   :range
	   :prompt-read
	   :zip-plist
	   :enumerate-hash-table
	   :slurp-stream4))

(in-package :com.cvberry.util)


;;;////////////////////////////////UTILITY CODE
(defmacro break-transparent (exp)
  `(let ((x ,exp)) (break "argument to break: ~:S" x) x))
(defun range (&key (min 0) (max 0) (step 1))
  "returns range from min to max inclusive of min
   exclusive of max"
   (loop for n from min below max by step
      collect n))
(defun prompt-read (prompt)
  (format *query-io* "~a: " prompt)
  (read-line *query-io*))
(defun zip-plist (keys values)
  "creates a plist from a list of keys and a list of values."
  (loop for k in keys
        for v in values nconc
       (list k v)))
(defun enumerate-hash-table (hasht)
  (maphash #'(lambda (k v) (format t "~a => ~a~%" k v)) hasht))

(defun slurp-stream4 (stream)
 (let ((seq (make-string (file-length stream))))
  (read-sequence seq stream)
  seq))

;;;////////////////////////////////
