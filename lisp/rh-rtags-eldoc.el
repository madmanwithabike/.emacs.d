;;; rh-rtags-eldoc.el --- ramblehead's rtags header line

;; Copyright (C) 2019 Victor Rybynok

;; Author: Victor Rybynok
;; URL: non yet
;; Package-Version: 20190321
;; Version: 0.0.0
;; Keywords: convenience c++ rtags
;; Package-Requires: ((emacs "26"))

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; This module configures rtags eldoc
;;
;;; Code:

(require 'rtags)
(require 'eldoc)

(defun rh-rtags-eldoc-fontify-string (str mode)
  "Return STR fontified according to MODE."
  (with-temp-buffer
    (insert str)
    (delay-mode-hooks (funcall mode))
    (font-lock-default-function mode)
    (font-lock-default-fontify-region
     (point-min) (point-max) nil)
    (buffer-string)))

(defun rh-rtags-eldoc-function ()
  (let ((summary (rtags-get-summary-text)))
    (when summary
      (setq summary
            (replace-regexp-in-string
             "[[:blank:]]*{.*$" ""
             (mapconcat
              (lambda (str)
                (if (= 0 (length str))
                    (setq str " // ")
                  ;; (string-trim str))
                  (< 0 (length str))
                  (setq str (string-trim str))
                  (let ((fst (aref str 0))
                        (lst (aref str (1- (length str)))))
                    (when (seq-contains ":" fst)
                      (setq str (concat " " str)))
                    (when (seq-contains ",>*&" lst)
                      (setq str (concat str " ")))))
                str)
              (split-string summary "\r?\n")
              "")))
      (setq summary (replace-regexp-in-string
                     "[[:blank:]]*//.*$" ""
                     summary))
      (setq summary (replace-regexp-in-string
                     "\\(.*[^:]\\):[^:].*$" "\\1"
                     summary))
      (setq summary (string-trim-right summary))
      (setq summary (replace-regexp-in-string
                     "[[:blank:]]\\{2,\\}" " "
                     summary))
      (setq summary (replace-regexp-in-string
                     "template<" "template <"
                     summary))
      (setq summary (replace-regexp-in-string
                     ">[[:blank:]]+>" ">>"
                     summary))
      (setq summary (replace-regexp-in-string
                     "\\(.+\\)[[:blank:]]+(" "\\1("
                     summary))
      ;; (setq summary (replace-regexp-in-string
      ;;                "[[:blank:]]*noexcept$" ""
      ;;                summary))
      (setq summary (rh-rtags-eldoc-fontify-string summary major-mode)))))

;;;###autoload
(defun rh-rtags-eldoc-setup ()
  (interactive)
  (setq-local eldoc-documentation-function #'rh-rtags-eldoc-function)
  (eldoc-mode 1))

(provide 'rh-rtags-eldoc)
;;; rh-rtags-eldoc.el ends here
