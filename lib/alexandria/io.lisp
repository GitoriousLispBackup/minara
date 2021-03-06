;; Copyright (c) 2002-2006, Edward Marco Baringer
;; All rights reserved.

(in-package :alexandria)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %expand-with-input/output-file (body direction stream-name file-name
                                         &rest args
                                         &key external-format
                                         &allow-other-keys)
    (remove-from-plistf args :external-format)
    (with-unique-names (body-fn)
      (once-only (external-format)
        `(flet ((,body-fn (,stream-name)
                  ,@body))
           ;; this is needed not to screw up the default external-format when not specified
           (if ,external-format
               (with-open-file (,stream-name ,file-name :direction ,direction
                                             :external-format ,external-format
                                             ,@args)
                 (,body-fn ,stream-name))
               (with-open-file (,stream-name ,file-name :direction ,direction ,@args)
                 (,body-fn ,stream-name))))))))

(defmacro with-input-from-file ((stream-name file-name &rest args
                                             &key (direction nil direction-p)
					     &allow-other-keys)
                                &body body)
  "Evaluate BODY with STREAM-NAME to an input stream on the file
FILE-NAME. ARGS is sent as is to the call to OPEN except EXTERNAL-FORMAT,
which is only sent to WITH-OPEN-FILE when it's not NIL."
  (declare (ignore direction))
  (when direction-p
    (error "Can't specifiy :DIRECTION for WITH-INPUT-FROM-FILE."))
  (apply '%expand-with-input/output-file body :input stream-name file-name args))

(defmacro with-output-to-file ((stream-name file-name &rest args
                                            &key (direction nil direction-p)
					     &allow-other-keys)
			       &body body)
  "Evaluate BODY with STREAM-NAME to an output stream on the file
FILE-NAME. ARGS is sent as is to the call to OPEN except EXTERNAL-FORMAT,
which is only sent to WITH-OPEN-FILE when it's not NIL."
  (declare (ignore direction))
  (when direction-p
    (error "Can't specifiy :DIRECTION for WITH-OUTPUT-TO-FILE."))
  (apply '%expand-with-input/output-file body :output stream-name file-name args))

(defun read-file-into-string (pathname &key (buffer-size 4096) external-format)
  "Return the contents of the file denoted by PATHNAME as a fresh string.

The EXTERNAL-FORMAT parameter will be passed directly to WITH-OPEN-FILE
unless it's NIL, which means the system default."
  (with-input-from-file
      (file-stream pathname :external-format external-format)
    (let ((*print-pretty* nil))
      (with-output-to-string (datum)
        (let ((buffer (make-array buffer-size :element-type 'character)))
	  (loop
	     :for bytes-read = (read-sequence buffer file-stream)
	     :do (write-sequence buffer datum :start 0 :end bytes-read)
	     :while (= bytes-read buffer-size)))))))

(defun write-string-into-file (string pathname &key (if-exists :error)
						    (if-does-not-exist :error)
                                                    external-format)
  "Write STRING to PATHNAME.

The EXTERNAL-FORMAT parameter will be passed directly to WITH-OPEN-FILE
unless it's NIL, which means the system default."
  (with-output-to-file (file-stream pathname :if-exists if-exists
				    :if-does-not-exist if-does-not-exist
				    :external-format external-format)
    (write-sequence string file-stream)))

(defun copy-file (from to &key (if-to-exists :supersede)
			       (element-type '(unsigned-byte 8)) finish-output)
  (with-input-from-file (input from :element-type element-type)
    (with-output-to-file (output to :element-type element-type
				    :if-exists if-to-exists)
      (copy-stream input output
                   :element-type element-type
                   :finish-output finish-output))))

(defun copy-stream (input output &key (element-type (stream-element-type input))
                    (buffer-size 4096)
                    (buffer (make-array buffer-size :element-type element-type))
                    finish-output)
  "Reads data from INPUT and writes it to OUTPUT. Both INPUT and OUTPUT must
be streams, they will be passed to READ-SEQUENCE and WRITE-SEQUENCE and must have
compatible element-types."
  (loop
     :for bytes-read = (read-sequence buffer input)
     :while (= bytes-read buffer-size)
     :do (write-sequence buffer output)
     :finally (progn
                (write-sequence buffer output :end bytes-read)
                (when finish-output
                  (finish-output output)))))
