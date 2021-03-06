;(ql:quickload :split-sequence)
;(ql:quickload :alexandria)
;(load "berryutils.lisp")
;;;word statistics package
;;;in cl-surf, used only to calculate the weight of search terms

(defpackage :com.cvberry.wordstat
  (:nicknames :wordstat)
  (:use :common-lisp :alexandria :com.cvberry.util)
  (:import-from :split-sequence :split-sequence)
  (:export :bootstrap-image
	   :num-words-in-hash
	   :*total-stat-store*
	   :*tothash*
	   :*totnum*
	   :make-file-stat
	   :standout-words-print
	   :calc-standout-words))

(in-package :com.cvberry.wordstat)

;;;////////////////////////////////FILE STAT CLASS
(defclass file-stat ()
  ((identifier :initarg :identifier :accessor identifier)
   (frequency-hash :initarg :frequency-hash :accessor frequency-hash)))

(defun file-stat-to-string (filestat)
  (with-slots (identifier frequency-hash) filestat
    (list 
     :identifier identifier
     :frequency-data (alist-plist (calc-wordlist frequency-hash)) ;plists are smaller...!
     ))) 

(defun write-file-stats-to-file (filestats filename header)
  (with-open-file (out filename :direction :output :if-exists :supersede)
    (with-standard-io-syntax
      (write-file-stats-to-stream filestats out header))))

(defun write-file-stat-to-file (filestat filename)
  (with-open-file (out filename :direction :output :if-exists :supersede)
    (with-standard-io-syntax
      (print (file-stat-to-string filestat) out))))

(defun write-file-stats-to-stream (filestats stream header)
  "takes in list of file-stat objects, a filename, and header text
   writes the filestats data and header in readable form to the file specified by filename"
  (print 
   (list :header header
	 (loop for filestat in filestats collecting
	      (file-stat-to-string filestat))) stream))

(defun read-file-stats-from-file (filename)
  (with-open-file (stream filename)
    (let ((ioraw ()))
      (with-standard-io-syntax
	(setf ioraw (read stream)))
      (let ((flist (nth 2 ioraw)))
	(loop for lst in flist collecting
	     (make-instance 'file-stat 
			    :identifier (getf lst :identifier)
			    :frequency-hash (plist-hash-table (getf lst :frequency-data) :test #'equal)))))))
;;;////////////////////////////////

;;;////////////////////////////////TOTWORDLIST STRUCT
(defstruct totwordlist
  "contains 1. number of words in this wordlist, 2. alist of words sorted by frequency
   3. hashtable of words"
  (:numwords 0)
  (:wordlist ())
  (:wordhash ()))
;;;////////////////////////////////


;;;////////////////////////////////GLOBALS
(defparameter *filelist* (directory "./brown2/*"))
(defvar *words-to-let-be* '("is" "pleased")) 
(defvar *suffixes-to-strip* '("'s" "s" "es" "s'" "ed" "ing"))
;;;////////////////////////////////

;;;////////////////////////////////PARSE FILES
(defun generate-file-stat (filename)
  "creates file-stat object from data accessed at filename"
  (with-open-file (stream filename)
    (let ((mhash (make-hash-table :test #'equalp)))
      (loop for line = (read-line stream nil) while line do 
	   (add-to-freq-table (split-and-strip line) mhash))
      (make-instance 'file-stat 
		     :identifier filename
		     :frequency-hash mhash))))

(defun generate-file-stats (file-list)
  "runs generate-file-stat for a list of files in the current directory"
  (loop for path in file-list collecting
       (generate-file-stat path)))
;;;////////////////////////////////

;;;////////////////////////////////PROCESS STRINGS
(defun split-and-strip (string)
  "takes in a string and a delimiter predicate of one variable,
   returns a list of stemmed words."
  ;;first clean out punctuation
  (let (
	(nstring 
	 (substitute-if-not 
	  #\Space 
	  #'(lambda (char) 
	      (let ((charcode (char-code char))) 
		(if (and
		     (not (eql charcode (char-code #\-))) ;leave dashes in place
		     (or (< charcode (char-code #\A))
			 (> charcode (char-code #\z))
			 (and
			  (> charcode (char-code #\Z))
			  (< charcode (char-code #\a)))))
		    nil
		    char))) 
	  string)))

					;now do some light/simple stemming of words, and split them up
    (loop for word in (split-sequence #\Space nstring  :remove-empty-subseqs t) collecting
	 (strip-word word))))

(defun strip-word (word)
  "this will need help before doing serious work w/ it."
  ;; (if (member-if #'(lambda (w2) (equal word w2)) *words-to-let-be*)
  ;;     (return-from strip-word word)) ;don't stem these words!
  ;; 					;now apply some stemming rules to everything else.
  ;; (loop for suffix in *suffixes-to-strip* do
  ;;      (if (>= (length word) (length suffix))
  ;; 	   (if 
  ;; 	    (do ((suffix-index (1- (length suffix)) (1- suffix-index))
  ;; 		 (word-index (1- (length word)) (1- word-index)))
  ;; 		((or (< suffix-index  0) (< word-index 0)) t)  ;returns true if the loop completes, no mismatches 
  ;; 	      (if (not (eql (elt word word-index) (elt suffix suffix-index)))
  ;; 		  (return nil)
  ;; 					;else continue
  ;; 		  ))
  ;; 	    (return-from strip-word (subseq word 0 (- (length word) (length suffix))))
  ;; 	    nil)))
  (return-from strip-word word)) ;if we get this far...

(defun make-file-stat (string-input identifier)
  (let ((mhash (make-hash-table :test #'equalp)))
    (add-to-freq-table (split-and-strip string-input) mhash)
    (make-instance 'file-stat :identifier identifier :frequency-hash mhash)))
;;;////////////////////////////////

;;;////////////////////////////////PROCESS FILE-STATS
(defun make-total-hash (file-stats-list)
  (let ((tothash (make-hash-table :test #'equalp)))
    (loop for filestat in file-stats-list do
	 (with-slots (frequency-hash) filestat 
	   (maphash 
	    (lambda (word fileval) 
	      (multiple-value-bind (v exists) (gethash word tothash)
		(if exists
		    (setf (gethash word tothash) (+ (gethash word tothash) (gethash word frequency-hash))) ;then the word is already in tothash, increment it
		    (setf (gethash word tothash) 1)))) ;adding for first time
	    frequency-hash)))
    tothash))

(defun num-words-in-hash (hasht)
  "returns number of total (with repetition) words in hasht"
  (let ((numwords 0))
    (maphash (lambda (k v) (setf numwords (+ numwords v))) hasht)
    numwords))

(defun calc-wordlist (hasht)
  "returns sorted alist of words and their respective percent frequencies"
  (let ((tot-num-words (num-words-in-hash hasht)))
    (sort (hash-table-alist hasht) #'> :key #'cdr)))

(defun normalize-wordlist (wordlist)
  (let ((numwords (loop for (a . b) in wordlist sum b)))
  (loop for (a . b) in wordlist collect
       (cons a (/ b numwords)))))

(defun calc-standout-words (smallhash bighash num-words-in-bighash)
  "returns weighted alist of standout words from smallhash.
 algorithm:  40 (((100*smallratio - 100*bigratio))/(1 + sqrt(bigratio))) "
  (let ((outlist ())
	(num-words-in-small (num-words-in-hash smallhash))) 
    (maphash (lambda (k v) 
	       (let* ((smallratio (* (/ v num-words-in-small) 100))
		      (bigvalue (multiple-value-bind (v exists) (gethash k bighash)
				  (if v v 0)))
		      (bigratio (* (/ bigvalue num-words-in-bighash) 100)))
		 (setf outlist (merge 'list outlist (list (cons k (* 40 (/ (- smallratio bigratio) (+ 1 (sqrt bigratio)))))) #'> :key #'cdr))))
	     smallhash)
    outlist)) 

(defun add-to-freq-table (wordlist freq-hash)
  "takes in alist of words, adds them to 'freq-hash'"
  (loop for word in wordlist do
       (multiple-value-bind (v exists) (gethash word freq-hash)
	 (if exists
	     (setf (gethash word freq-hash) (1+ v))
					;^then we shall increment the word count for this word!
	     (setf (gethash word freq-hash) 1) 
					;^else we are adding the first occurrence of this word.
	     ))))


(defun hasht1-diffscore-hasht2 (hasht1 hasht2 
				&optional (words-of-interest 
					   (let ((words ()))
					     (maphash (lambda (k v) (push k words)) hasht1)
					     words)))
  (/ (* (hash-table-count hasht1) 
	(let ((numwordsin1 (num-words-in-hash hasht1))
	      (numwordsin2 (num-words-in-hash hasht2)))
	  (loop for k in words-of-interest summing
	       (let ((afreq (/ (gethash k hasht1 0) numwordsin1))
		     (bfreq (/ (gethash k hasht2 1) numwordsin2)))
		 ;;here our formula is ch-square ish...
		 (/ (expt (- afreq bfreq) 2) bfreq)))))
     (length words-of-interest))) ;this line attempts to normalize for a smaller selection of words.

(defun calc-hasht-diff (hashta hashtb &optional words-of-interestab)
  "this compares the freq tables in both orders, then averages the result.
   supply list of form (woia woib) to specify which words to consider for each hash."
  (if words-of-interestab
      (destructuring-bind (woia woib) words-of-interestab
	(/ (+ (hasht1-diffscore-hasht2 hashta hashtb woia) 
	      (hasht1-diffscore-hasht2 hashtb hashta woib)) 2))
      (/ (+ (hasht1-diffscore-hasht2 hashta hashtb) 
	    (hasht1-diffscore-hasht2 hashtb hashta)) 2)))

(defun diff-hasht-important-words (hashta hashtb bighash)
  "this function takes the standout words from hashta and hashtb and uses
   them for the diff operation.  "
  (let* ((n-words-in-big (num-words-in-hash bighash))
	 (acutoff (ceiling (/ (hash-table-count hashta) 15))) 
	 (bcutoff (ceiling (/ (hash-table-count hashtb) 15))) 
	 (a-important (mapcar (lambda (entry) (car entry)) (subseq (calc-standout-words hashta bighash n-words-in-big) 0 acutoff)))
	 (b-important (mapcar (lambda (entry) (car entry)) (subseq (calc-standout-words hashtb bighash n-words-in-big) 0 bcutoff))))
	 (calc-hasht-diff hashta hashtb (list a-important b-important))
	 ))
;;;////////////////////////////////


;;;////////////////////////////////INTERACTIVE HELPERS
(defun standout-words-print (standout-words)
  (loop for (a . b) in standout-words do
       (loop repeat (round b) do 
	    (format t "~a" "="))
       (format t "> ~a ~$~%" a b)))
;;;////////////////////////////////

;;;////////////////////////////////STUFF TO GET IMAGE SET UP USEFULLY
(defparameter *tot-file-stats* ())
(defparameter *tothash* ())
(defparameter *totnum* ())
(defparameter *total-stat-store* ())

(defun bootstrap-image ()
  (setf *tot-file-stats* (generate-file-stats (directory "./brown2/*")))
  (setf *tothash* (make-total-hash *tot-file-stats*))
  (setf *brownstat* (make-instance 'file-stat :frequency-hash *tothash* :identifier "Brown Corpus Frequency Statistics"))
  (let* ((wordlist (calc-wordlist *tothash*))
	 (numwords (length wordlist)))
    (setf *total-stat-store* (make-totwordlist :numwords numwords :wordlist wordlist :wordhash *tothash*))
    (setf *totnum* numwords)))


(defparameter *standouts* ())
;;;useful function to take a look at when rebuilding image...
;; (defun interactive-suggestions()
;;   (setf *standouts* (calc-standout-words 
;; 		     (slot-value (generate-file-stat "/home/vancan1ty/shared/1332Project/NYTimesIranArticle.txt") 'frequency-hash)
;; 		     (slot-value *total-stat-store* :wordhash)
;; 		     (slot-value *total-stat-store* :numwords)))
;;   (subseq *standouts* 0 50)
;;   (setf *wsj-iran* (generate-file-stat "/home/vancan1ty/shared/1332Project/wsjiranarticle.txt"))
;;   (setf *wsj-financial* (generate-file-stat "/home/vancan1ty/shared/1332Project/wsjfinancialarticle.txt"))
;;   (setf *nytimes-iran* (generate-file-stat "/home/vancan1ty/shared/1332Project/NYTimesIranArticle.txt"))
;;   (setf *wp-iran* (generate-file-stat "/home/vancan1ty/shared/1332Project/washingtonpost_old_iran_article.txt"))

;;   (format t "~$~%" (calc-hasht-diff  (frequency-hash *wsj-iran*) (frequency-hash *wsj-financial* )))
;;   (format t "~$~%" (calc-hasht-diff  (frequency-hash *nytimes-iran*) (frequency-hash *wsj-iran*)))

;;   (format t "~$~%" (diff-hasht-important-words  (frequency-hash *wsj-iran*) (frequency-hash *nytimes-iran* ) *tothash*))
;;   (standout-words-print (calc-standout-words (frequency-hash *wsj-iran*) *tothash* (num-words-in-hash *tothash*)))
;;   )
;; ;;;////////////////////////////////
