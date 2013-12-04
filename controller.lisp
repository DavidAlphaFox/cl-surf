(defpackage :com.cvberry.controller
  (:nicknames :controller)
  (:use :common-lisp :alexandria :com.cvberry.util)
  (:import-from :com.cvberry.file-index :pathescape)
  (:import-from :com.cvberry.wordstat :bootstrap-image :*tothash* :*totnum*)
  (:import-from :com.cvberry.crawler :index-sites-wrapper :create-standard-index-site-p)
  (:import-from :com.cvberry.searcher :run-text-search)
  (:import-from :com.cvberry.mem-cache-handler :init-memcache :update-memcache)
  (:export :setup-search
	   :run-search
	   :*tinfo*
	   :*currentsite*
	   :init-totnum-tothash
	   :site-index-info-visited-hash
	   :site-index-info-memcache
	   :site-index-info-directory
	   :run-html-search
	   ))

(in-package :com.cvberry.controller)

(defstruct site-index-info
  (visited-hash ())
  (memcache ())
  (directory ()))

(defvar *tinfo* ())
(defvar *totnum* ())
(defvar *tothash* ())

(defparameter cvberrysite
  (list :siteroot "http://www.cvberry.com"
	:stayonsite t
	:depth 3
	:directory "cvberryindex/"))

(defparameter sossite 
  (list :siteroot "http://www.sosmath.com"
	:stayonsite t
	:depth 4
	:directory "sosindex/"))


(defparameter *currentsite* sossite)

(defun setup-search-wrapper ()
  (setf *tinfo* (setup-search 
			      (getf *currentsite* :siteroot) 
			      (getf *currentsite* :directory) 
			      (getf *currentsite* :stayonsite) 
			      (getf *currentsite* :depth))))

(defun setup-search (baseurl directory stayonsite depth)
  (if (not (boundp '*tothash*))
      (com.cvberry.wordstat:bootstrap-image))
  (let* (;(mdirectory (concatenate 'string "index_" (pathescape baseurl) "/"))
	 (mdirectory directory)
	 (mvisited-hash
	  (crawler:index-sites-wrapper (list baseurl) depth mdirectory (crawler:create-standard-index-site-p 1000) :stay-on-sites t))
	 (mmemcache (mchandler:init-memcache (concatenate 'string mdirectory "*.*"))))
    (make-site-index-info :visited-hash mvisited-hash :memcache mmemcache :directory mdirectory)))

(defun restore-search ()
  (setf (site-index-info-visited-hash *tinfo*) 
	(alist-hash-table 
	 (loop for file in 
	      (directory (concatenate 'string (getf *currentsite* :directory) "*.*")) collect
	      (let ((filecontents (with-open-file (stream file) (with-standard-io-syntax (read stream)))))
		(cons (getf filecontents :url) (getf filecontents :timeindexed))))))
  (setf (site-index-info-memcache *tinfo*)
	(mchandler:init-memcache (concatenate 'string (getf *currentsite* :directory) "*.*")))
  (setf (site-index-info-directory *tinfo*) (getf *currentsite* :directory)))


(defun run-search (siteindexinfo querytext start end)
  (with-slots (visited-hash memcache directory) siteindexinfo
    (searcher:run-text-search memcache directory querytext start end)))

(defun run-html-search (siteindexinfo querytext start end)
  (with-slots (visited-hash memcache directory) siteindexinfo
    (searcher:run-html-search memcache directory querytext start end)))

(defun init-totnum-tothash ()
  (let ((totdata (with-open-file (stream "totdata.lisp") (read stream))))
    (setf *totnum* (getf totdata :totnum))
    (setf *tothash* (alist-hash-table (getf totdata :tothash))))
  ())
