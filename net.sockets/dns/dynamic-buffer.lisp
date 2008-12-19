;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil -*-
;;;
;;; --- Read/write adjustable buffer.
;;;

(in-package :net.sockets)

(defclass dynamic-buffer ()
  ((sequence     :initform nil  :accessor sequence-of)
   (read-cursor  :initform 0    :accessor read-cursor-of)
   (write-cursor :initform 0    :accessor write-cursor-of)))

(defmethod initialize-instance :after ((buffer dynamic-buffer)
                                       &key (size 256) sequence (start 0) end)
  (etypecase sequence
    (null
     (setf (sequence-of buffer) (make-array size :element-type 'ub8)))
    (ub8-vector
     (check-bounds sequence start end)
     (let* ((sequence-size (- end start))
            (newseq (make-array sequence-size :element-type 'ub8)))
       (replace newseq sequence :start2 start :end2 end)
       (setf (sequence-of buffer)     newseq
             (write-cursor-of buffer) sequence-size)))))

(defmethod print-object ((buffer dynamic-buffer) stream)
  (print-unreadable-object (buffer stream :type t :identity t)
    (let ((*print-length* 40))
      (format stream "Size: ~A RC: ~A WC: ~A Contents: ~S"
              (size-of buffer)
              (read-cursor-of buffer)
              (write-cursor-of buffer)
              (sequence-of buffer)))))

(defmethod size-of ((buffer dynamic-buffer))
  (length (sequence-of buffer)))

(declaim (inline ub16-to-vector))
(defun ub16-to-vector (value)
  (vector (ldb (byte 8 8) value)
          (ldb (byte 8 0) value)))

(declaim (inline ub32-to-vector))
(defun ub32-to-vector (value)
  (vector (ldb (byte 8 32) value)
          (ldb (byte 8 16) value)
          (ldb (byte 8 8) value)
          (ldb (byte 8 0) value)))

(defun maybe-grow-buffer (buffer vector)
  (with-accessors ((seq sequence-of)
                   (size size-of)
                   (wcursor write-cursor-of))
      buffer
    (let ((vlen (length vector)))
      (when (< size (+ wcursor vlen))
        (let ((newsize (* 3/2 (+ size vlen))))
          (setf seq (adjust-array seq newsize))))))
  (values buffer))

(defun write-vector (buffer vector)
  (maybe-grow-buffer buffer vector)
  (with-accessors ((seq sequence-of)
                   (wcursor write-cursor-of))
      buffer
    (let ((vlen (length vector)))
      (replace seq vector :start1 wcursor)
      (incf wcursor vlen)))
  (values buffer))

(declaim (inline write-ub8))
(defun write-ub8 (buffer value)
  (write-vector buffer (vector value)))

(declaim (inline write-ub16))
(defun write-ub16 (buffer value)
  (write-vector buffer (ub16-to-vector value)))

(declaim (inline write-ub32))
(defun write-ub32 (buffer value)
  (write-vector buffer (ub32-to-vector value)))

(define-condition dynamic-buffer-input-error (error)
  ((buffer :initform (error "Must supply buffer")
           :initarg :buffer :reader buffer-of)))

(define-condition input-buffer-eof (dynamic-buffer-input-error)
  ((octets-requested :initarg :requested :reader octets-requested)
   (octets-remaining :initarg :remaining :reader octets-remaining))
  (:report (lambda (condition stream)
             (format stream "You requested ~a octets but only ~A are left in the buffer"
                     (octets-requested condition)
                     (octets-remaining condition))))
  (:documentation
   "Signals that an INPUT-BUFFER contains less unread bytes than requested."))

(define-condition input-buffer-index-out-of-bounds (dynamic-buffer-input-error) ()
  (:documentation
   "Signals that DYNAMIC-BUFFER-SEEK-READ-CURSOR on an INPUT-BUFFER was passed an
invalid offset."))

(defun seek-read-cursor (buffer place &optional offset)
  (with-accessors ((seq sequence-of)
                   (size size-of)
                   (rcursor read-cursor-of))
      buffer
    (ecase place
      (:start (setf rcursor 0))
      (:end   (setf rcursor size))
      (:offset
       (check-type offset unsigned-byte "an unsigned-byte")
       (if (>= offset size)
           (error 'input-buffer-index-out-of-bounds :buffer buffer)
           (setf rcursor offset))))))

(declaim (inline unread-bytes))
(defun unread-bytes (buffer)
  (- (write-cursor-of buffer) (read-cursor-of buffer)))

(defun read-vector (buffer length)
  (with-accessors ((seq sequence-of)
                   (rcursor read-cursor-of))
      buffer
    (let* ((bytes-to-read (min (unread-bytes buffer) length))
           (newvector (make-array bytes-to-read :element-type 'ub8)))
      (replace newvector seq :start2 rcursor)
      (incf rcursor bytes-to-read)
      (values newvector))))

(defmacro read-ub-be (vector position &optional (length 1))
  `(+ ,@(loop :for i :below length
              :collect `(ash (aref ,vector (+ ,position ,i))
                             ,(* (- length i 1) 8)))))

(declaim (inline read-ub16-from-vector))
(defun read-ub16-from-vector (vector position)
  (read-ub-be vector position 2))

(declaim (inline read-ub32-from-vector))
(defun read-ub32-from-vector (vector position)
  (read-ub-be vector position 4))

(declaim (inline check-if-enough-bytes))
(defun check-if-enough-bytes (buffer length)
  (let ((remaining-bytes (unread-bytes buffer)))
    (when (< remaining-bytes length)
      (error 'input-buffer-eof
             :buffer buffer
             :requested length
             :remaining remaining-bytes))))

(declaim (inline read-ub8))
(defun read-ub8 (buffer)
  (check-if-enough-bytes buffer 1)
  (prog1
      (aref (sequence-of buffer) (read-cursor-of buffer))
    (incf (read-cursor-of buffer))))

(declaim (inline read-ub16))
(defun read-ub16 (buffer)
  (check-if-enough-bytes buffer 2)
  (prog1
      (read-ub16-from-vector (sequence-of buffer) (read-cursor-of buffer))
    (incf (read-cursor-of buffer) 2)))

(declaim (inline read-ub32))
(defun read-ub32 (buffer)
  (check-if-enough-bytes buffer 4)
  (prog1
      (read-ub32-from-vector (sequence-of buffer) (read-cursor-of buffer))
    (incf (read-cursor-of buffer) 4)))
