;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil -*-
;;;
;;; etc-files.lisp --- Common parsing routines for /etc namedb files.
;;;
;;; Copyright (C) 2006-2008, Stelian Ionescu  <sionescu@common-lisp.net>
;;;
;;; This code is free software; you can redistribute it and/or
;;; modify it under the terms of the version 2.1 of
;;; the GNU Lesser General Public License as published by
;;; the Free Software Foundation, as clarified by the
;;; preamble found here:
;;;     http://opensource.franz.com/preamble.html
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU Lesser General
;;; Public License along with this library; if not, write to the
;;; Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
;;; Boston, MA 02110-1301, USA

(in-package :net.sockets)

(defun space-char-p (char)
  (declare (type character char))
  (or (char= char #\Space)
      (char= char #\Tab)))

(defun split-etc-tokens (line)
  (declare (type string line))
  (let ((comment-start (position #\# line)))
    (split-sequence-if #'space-char-p line
                       :remove-empty-subseqs t
                       :start 0 :end comment-start)))

(defmacro serialize-etc-file (file)
  `(#msplit-etc-tokens (scan-file ,file #'read-line)))