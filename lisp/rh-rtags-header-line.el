;;; rh-rtags-header-line.el --- ramblehead's rtags header line

;; Copyright (C) 2018 Victor Rybynok

;; Author: Victor Rybynok
;; URL: non yet
;; Package-Version: 20180430
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
;; This module configures rtags header line to display current point location
;; within C++ function/class/namespace - the way ramblehead likes it :)
;;
;;; Code:

(require 'rtags)
(require 'cl)
(require 'rh-window-selected-interactively-p)

(defvar rh-header-line-trim-indicator "›")
(defvar rh-header-line-beginning-indicator " ")

(defun rh-rtags-header-line ()
  (when (not (local-variable-p 'rh-window-current-container-alist))
    (set (make-local-variable 'rh-window-current-container-alist) nil))
  (setq rh-window-current-container-alist
        (cl-delete-if (lambda (win-cont)
                        (not (window-live-p (car win-cont))))
                      rh-window-current-container-alist))
  (let* ((current-container (or rtags-cached-current-container ""))
         (win (selected-window))
         (win-cont (assoc win rh-window-current-container-alist)))
    (if (rh-window-selected-interactively-p)
        (if (null win-cont)
            (add-to-list 'rh-window-current-container-alist
                         `(,win . ,current-container))
          (setf (cdr win-cont) (copy-sequence current-container)))
      (when win-cont
        (setq current-container (cdr win-cont))))
    (propertize
     (let* ((header-string (concat rh-header-line-beginning-indicator
                                   current-container))
            (header-string-width (string-width header-string))
            (header-filler-width (- (window-total-width) header-string-width)))
       (if (< header-filler-width 0)
           (concat (substring header-string
                              0 (- (window-total-width)
                                   (string-width rh-header-line-trim-indicator)))
                   rh-header-line-trim-indicator)
         (concat header-string (make-string header-filler-width ?\ ))))
     'face (if (rh-window-selected-interactively-p)
               'mode-line
             'mode-line-inactive))))

(add-hook 'buffer-list-update-hook
          (lambda ()
            (when (bound-and-true-p rtags-track-container)
              (run-with-timer
               0 nil
               #'rtags-update-current-container-cache))))

;; (run-with-timer
;;  0 0.5
;;  (lambda ()
;;    (when (bound-and-true-p rtags-track-container)
;;      (rtags-update-current-container-cache))))

(defun rh-rtags-header-line-find-file-handler ()
  (setq-local header-line-format '(:eval (rh-rtags-header-line))))

;;;###autoload
(defun rh-rtags-header-line-setup ()
  ;; Display current function name at the top of the window (header-line).
  ;; https://github.com/Andersbakken/rtags/issues/435
  (setq-local rtags-cached-current-container "")
  (setq-local rtags-track-container t)
  (add-hook 'find-file-hook #'rh-rtags-header-line-find-file-handler nil t))

(provide 'rh-rtags-header-line)
;;; rh-rtags-header-line.el ends here
