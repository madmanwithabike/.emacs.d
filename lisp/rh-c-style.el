;;; rh-c-style.el --- ramblehead's C++ indentation tweaks for google-c-style

;; Copyright (C) 2018 Victor Rybynok

;; Author: Victor Rybynok
;; URL: non yet
;; Package-Version: 20180430
;; Version: 0.0.0
;; Keywords: indentation c++ cc-mode google-c-style
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
;; This module attempts sets indentation - the way ramblehead likes it :)
;;
;;; Code:

(require 'google-c-style)

(defun rh-c++-looking-at-guess-macro-definition (langelem)
  "Return t if the guess is that we are looking at macro definition"
  (let ((case-fold-search nil))
    (or (looking-at "\\b[A-Z0-9_]+(.*)[ \t]*$")
        (looking-at "\\b[A-Z0-9_]+[ \t]*$"))))

(defun rh-c++-looking-at-return (langelem)
  "Return t if looking at return statement"
  (looking-at "return"))

(defun rh-c++-get-offset-return (langelem)
  "Returns offset for the next line after sptit return"
  (ignore-errors
    (save-excursion
      (goto-char (c-langelem-pos langelem))
      (save-match-data
        (let ((line (thing-at-point 'line t)))
          (if (string-match "\\(return[[:space:]]+\\)[^[:space:]]+.*\n" line)
              ;; `(add ,(length (match-string 1 line)) +)

              ;; e.g.
              ;; return glowplugMeasurement > glowplugMin &&
              ;;        glowplugMeasurement < glowplugMax;
              (length (match-string 1 line))

            '+))))))

;; (defun rh-c++-get-offset-bol-namespace-switch (langelem)
;;   "Returns offset for the next line after sptit return"
;;   (ignore-errors
;;     (save-excursion
;;       (let ((current-line-num (line-number-at-pos))
;;             (current-pos (point))
;;             langelem-line-num)
;;         (goto-char (c-langelem-pos langelem))
;;         (setq langelem-line-num (line-number-at-pos))
;;         (if (eq (- current-line-num langelem-line-num) 1)
;;             '+
;;           (goto-char current-pos)
;;           (back-to-indentation)
;;           (c-backward-syntactic-ws)
;;           (back-to-indentation)
;;           (if (rh-c++-looking-at-bol-namespace-switch langelem)
;;               `[,(current-column)]
;;             '++))))))

;; (defun rh-c++-get-offset-bol-namespace-switch (langelem)
;;   "Returns offset for the next line after sptit return"
;;   (ignore-errors
;;     (save-excursion
;;       (let ((current-line-num (line-number-at-pos))
;;             (current-pos (point))
;;             langelem-line-num)
;;         (goto-char (c-langelem-pos langelem))
;;         (setq langelem-line-num (line-number-at-pos))
;;         (if (eq (- current-line-num langelem-line-num) 1)
;;             '+
;;           (goto-char current-pos)
;;           (back-to-indentation)
;;           (c-backward-syntactic-ws)
;;           (back-to-indentation)
;;           `[,(current-column)])))))

(defun rh-c++-looking-at-multiline_arg (langelem)
  (back-to-indentation)
  (save-match-data
    (c-backward-syntactic-ws)
    (left-char)
    (and (not (looking-at ","))
         (not (looking-at "\"")))))

(defun rh-c++-looking-at-uniform_init_block_closing_brace_line (langelem)
  "Return t if cursor if looking at C++11 uniform init block T v {xxx}
closing brace"
  (back-to-indentation)
  (looking-at "}"))

(defun rh-c++-looking-at-uniform_init_block_cont_item (langelem)
  "Return t if cursor if looking at C++11 uniform init block
continuing (not first) item"
  (back-to-indentation)
  (c-backward-syntactic-ws)
  (looking-back ","))

(defun rh-c++-looking-at-class_in_namespace (langelem)
  "Return t if looking at topmost-intro class in namespace"
  (back-to-indentation)
  (let* ((c-parsing-error nil)
         (syntax (c-save-buffer-state nil
                   (c-guess-basic-syntax))))
    (and (equal (car (nth 0 syntax)) 'innamespace)
         (equal (car (nth 1 syntax)) 'topmost-intro)
         (looking-at "class"))))

(defun rh-c++-looking-at-template (langelem)
  "Return t if looking at class template"
  (if (looking-at "template") t nil))

;; (defun rh-c++-looking-at-bol-namespace-switch (langelem)
;;   "Returnt t if looking at '.', '->' or '::' at the begining of line"
;;   (back-to-indentation)
;;   (if (or (looking-at "\\.")
;;           (looking-at "->")
;;           (looking-at "::"))
;;       t nil))

(defun rh-c-style-examine (langelem looking-at-p)
  (and (equal major-mode 'c++-mode)
       (ignore-errors
         (save-excursion
           (funcall looking-at-p langelem)))))

(defun rh-c-style-examine-at-langelem (langelem looking-at-p)
  (and (equal major-mode 'c++-mode)
       (ignore-errors
         (save-excursion
           ;; (when langelem
           ;;   (goto-char (c-langelem-pos langelem)))
           (goto-char (c-langelem-pos langelem))
           (funcall looking-at-p langelem)))))

;; Adapted from google-c-lineup-expression-plus-4
(defun rh-c++-lineup-expression-plus-tab-width (langelem)
  (save-excursion
    (back-to-indentation)
    ;; Go to beginning of *previous* line:
    (c-backward-syntactic-ws)
    (back-to-indentation)
    (cond
     ;; We are making a reasonable assumption that if there is a control
     ;; structure to indent past, it has to be at the beginning of the line.
     ((looking-at "\\(\\(if\\|for\\|while\\)\\s *(\\)")
      (goto-char (match-end 1)))
     ;; For constructor initializer lists, the reference point for line-up is
     ;; the token after the initial colon.
     ((looking-at ":\\s *")
      (goto-char (match-end 0))))
    (vector (+ tab-width (current-column)))))

;;;###autoload
(defun rh-c-style-setup ()
  (setq tab-width 2)
  (google-set-c-style)

  ;; (c-set-offset 'statement-cont '(nil c-lineup-assignments +))
  (c-set-offset 'arglist-intro 'rh-c++-lineup-expression-plus-tab-width)
  ;; (c-set-offset 'inher-intro '+)
  (c-set-offset 'func-decl-cont '+)
  (c-set-offset 'inher-intro '++)
  (c-set-offset 'member-init-intro '++)

  (c-set-offset
   'arglist-cont
   (lambda (langelem)
     (cond
      ((rh-c-style-examine
        langelem
        #'rh-c++-looking-at-multiline_arg)
       '+))))

  ;; (c-set-offset
  ;;  'arglist-cont
  ;;  (lambda (langelem)
  ;;    (cond
  ;;     ;; ((rh-c-style-examine-at-langelem
  ;;     ;;   langelem
  ;;     ;;   #'rh-c++-looking-at-guess-macro-definition)
  ;;     ;;  nil)
  ;;     ;; ((rh-c-style-examine-at-langelem
  ;;     ;;   langelem
  ;;     ;;   #'rh-c++-looking-at-template)
  ;;     ;;  0)
  ;;     ;; ((rh-c-style-examine-at-langelem
  ;;     ;;   nil
  ;;     ;;   #'rh-c++-looking-at-bol-namespace-switch)
  ;;     ;;  (rh-c++-get-offset-bol-namespace-switch langelem))
  ;;     )))

  (c-set-offset
   'topmost-intro-cont
   (lambda (langelem)
     (cond
      ((rh-c-style-examine-at-langelem
        langelem
        #'rh-c++-looking-at-guess-macro-definition)
       nil)
      ((rh-c-style-examine-at-langelem
        langelem
        #'rh-c++-looking-at-template)
       0)
      (t '+))))

  ;; (c-set-offset 'topmost-intro-cont '+)

  ;; (c-set-offset
  ;;  'topmost-intro-cont
  ;;  (lambda (langelem)
  ;;    (if (rh-c-style-examine-at-langelem
  ;;         langelem
  ;;         #'rh-c++-looking-at-guess-macro-definition)
  ;;        nil
  ;;      0)))

  ;; (c-set-offset
  ;;  'topmost-intro-cont
  ;;  (lambda (langelem)
  ;;    (message "%s" langelem)
  ;;    (if (rh-c-style-examine-at-langelem
  ;;         langelem
  ;;         #'rh-c++-looking-at-template)
  ;;        nil
  ;;      '+)))

  ;; (c-set-offset
  ;;  'inher-intro
  ;;  (lambda (langelem)
  ;;    (if (rh-c-style-examine-at-langelem
  ;;         langelem
  ;;         #'rh-c++-looking-at-class_in_namespace)
  ;;        '++
  ;;      '++)))

  (c-set-offset
   'statement-cont
   (lambda (langelem)
     (cond
      ((rh-c-style-examine-at-langelem
        langelem
        #'rh-c++-looking-at-return)
       (rh-c++-get-offset-return langelem))
      ((rh-c-style-examine-at-langelem
        nil
        #'rh-c++-looking-at-uniform_init_block_closing_brace_line)
       '-)
      ((rh-c-style-examine-at-langelem
        nil
        #'rh-c++-looking-at-uniform_init_block_cont_item)
       0)
      ((rh-c-style-examine-at-langelem
        nil
        #'rh-c++-looking-at-bol-namespace-switch)
       (rh-c++-get-offset-bol-namespace-switch langelem))
      (t '(nil c-lineup-assignments +)))))

  (c-set-offset
   'defun-block-intro
   (lambda (langelem)
     (let ((syntax (if (boundp 'c-syntactic-context)
		       c-syntactic-context
		     (c-save-buffer-state nil
		       (c-guess-basic-syntax)))))
       (if (member '(inlambda) syntax)
           (lambda (langelem)
             (save-excursion
               (goto-char (c-langelem-pos langelem))
               `(add [,(current-column)] +)))
         '+))))

  (c-set-offset
   'inline-close
   (lambda (langelem)
     (let ((syntax (if (boundp 'c-syntactic-context)
		       c-syntactic-context
		     (c-save-buffer-state nil
		       (c-guess-basic-syntax)))))
       (if (member '(inlambda) syntax)
           (lambda (langelem)
             (save-excursion
               (goto-char (c-langelem-pos langelem))
               `[,(current-column)]))
         nil))))

  ;; (c-set-offset
  ;;  'statement-block-intro
  ;;  (lambda (langelem)
  ;;    (if (rh-c-style-examine-at-langelem
  ;;         langelem
  ;;         #'rh-c++-looking-at-lambda_in_uniform_init)
  ;;        0
  ;;      '+)))

  ;; see http://stackoverflow.com/questions/23553881/emacs-indenting-of-c11-lambda-functions-cc-mode
  ;; (defadvice c-lineup-arglist (around
  ;;                              rh-c++-c-lineup-arglist (_langelem)
  ;;                              activate)
  ;;   "Improve indentation of continued C++11 lambda function opened as argument."
  ;;   (setq ad-return-value
  ;;         (if (rh-c-style-examine-at-langelem
  ;;              _langelem
  ;;              #'rh-c++-looking-at-lambda_as_param)
  ;;             0
  ;;           ad-do-it)))
  )

(provide 'rh-c-style)
;;; rh-c-style.el ends here
