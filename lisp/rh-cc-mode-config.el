;;; rh-cc-mode-config.el --- ramblehead's rtags header line

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
;; This module provides cc-mode config
;;
;;; Code:

(require 'company-rtags)
(require 'company-clang)
(require 'company-c-headers)

;; (company-clang 'init)
;; (company-rtags 'init)

;;;###autoload
(defun rh-cc-company-setup ()
  (setq company-backends
        '(company-c-headers (company-keywords company-dabbrev-code)
          company-files (company-dabbrev company-ispell)))

  (bind-key "C-c C-<tab>" #'company-rtags c-mode-base-map)
  (bind-key "C-x C-<tab>" #'company-clang c-mode-base-map)

  (company-mode 1))

;; (defun rh-c++-auto-complete-clang ()
;;   (interactive)
;;   (message "auto-completing with clang...")
;;   (auto-complete (append '(ac-source-clang) ac-sources)))

;; ;;;###autoload
;; (defun rh-c++-auto-complete-setup ()
;;   (require 'auto-complete-clang)
;;   (setq-local ac-sources
;;               (append '(ac-source-c-headers
;;                         ;; Dynamic auto-completion is slow and interferes with
;;                         ;; typing, whether it is 'c-source-clang' or
;;                         ;; 'ac-source-rtags', therefore it is only activated on
;;                         ;; 'C-x C-<tab>' (see key definitions below in this
;;                         ;; function) in 'rh-c++-auto-complete-clang' function.
;;                         ;; ac-source-clang ac-source-rtags
;;                         )
;;                       ac-sources)))

(provide 'rh-cc-mode-config)
;;; rh-cc-mode-config.el ends here
