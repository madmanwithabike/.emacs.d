;; /b/{ ido

;; (ido-mode 1)
;; (setq ido-enable-flex-matching t)
;; (setq ido-case-fold t)
;; (setq ido-use-filename-at-point nil)
;; (setq ido-use-url-at-point nil)
;; (setq ido-save-directory-list-file vr-ido-last-file-path)
;; (setq ido-ignore-buffers rh-ignore-buffers)

;; (ido-everywhere 1)

;; (setq ido-confirm-unique-completion t)
;; (setq confirm-nonexistent-file-or-buffer nil)

;; ido-ubiquitous mode

;; (defvar ido-ubiquitous-debug-mode nil)

;; (require 'ido-ubiquitous)
;; (ido-ubiquitous-mode 1)
;; (setq ido-ubiquitous-max-items 50000)

;; smex mode

;; (setq smex-save-file vr-smex-save-file)
;; (require 'smex)
;; (smex-initialize)

;; (global-set-key (kbd "M-x") 'smex)
;; (global-set-key (kbd "M-X") 'smex-major-mode-commands)
;; (global-set-key (kbd "C-c C-c M-x") 'execute-extended-command)

;; (use-package ido-vertical-mode
;;   :config
;;   (ido-vertical-mode 1)
;;   :ensure t)

;; (use-package flx-ido
;;   :init
;;   (setq ido-enable-flex-matching t)
;;   (setq ido-use-faces nil)
;;   :config
;;   (flx-ido-mode 1)
;;   :ensure t)

;; /b/} ido

;; /b/{ helm

;; (defun vr-helm-toggle-header-line ()
;;   (if (= (length helm-sources) 1)
;;       (set-face-attribute 'helm-source-header nil :height 0.1)
;;     (set-face-attribute 'helm-source-header nil :height 1.0)))

;; (use-package helm
;;   :init
;;   (add-to-list 'display-buffer-alist
;;                `(,(rx bos "*helm" (* not-newline) "*" eos)
;;                  (display-buffer-in-side-window)
;;                  (inhibit-same-window . t)
;;                  (window-height . 0.2)))

;;   (setq helm-display-header-line nil)

;;   (add-hook 'helm-before-initialize-hook 'vr-helm-toggle-header-line)
;;   :ensure t)

;; /b/} helm

;; /b/{ tern

(use-package tern
  :config
  ;; (setq tern-command
  ;;       '("/home/rh/artizanya/arango/arangodb-typescript-setup/node_modules/.bin/tern"))

  ;; (defvar rh-tern-argument-hints-enabled t)

  ;; (defun tern-argument-hint-at-point ()
  ;;   (interactive)
  ;;   (tern-update-argument-hints-async))

  ;; (defun tern-post-command ()
  ;;   (unless (eq (point) tern-last-point-pos)
  ;;     (setf tern-last-point-pos (point))
  ;;     (setf tern-activity-since-command tern-command-generation)
  ;;     (when rh-tern-argument-hints-enabled
  ;;       (tern-update-argument-hints-async))))

  ;; (define-key tern-mode-keymap (kbd "M-.") nil)
  ;; (define-key tern-mode-keymap (kbd "M-,") nil)
  ;; (define-key tern-mode-keymap (kbd "C-c M-.") #'tern-find-definition)
  ;; (define-key tern-mode-keymap (kbd "C-c M-[") #'tern-pop-find-definition)
  ;; (define-key tern-mode-keymap (kbd "C-c M-i") #'tern-argument-hint-at-point)

  (define-key tern-mode-keymap (kbd "M-.") nil)
  (define-key tern-mode-keymap (kbd "M-,") nil)
  (define-key tern-mode-keymap (kbd "M-.") #'tern-find-definition)
  (define-key tern-mode-keymap (kbd "M-[") #'tern-pop-find-definition)

  (add-hook
   'tern-mode-hook
   (lambda ()
     (require 'company-tern)))

  :ensure t)

;; /b/} tern

;; /b/{ company-tern

(use-package company-tern
  :config
;;   (defun company-tern-annotation (candidate)
;;     "Return simplified type annotation. 'f' for functions and
;; 'p' for anything else."
;;     (if (company-tern-function-p candidate) "f trn" "p trn"))

  :after (company tern)
  :ensure t)

;; /b/} company-tern

;; /b/{ xref-js2

;; (use-package xref-js2
;;   :config
;;   (setq xref-js2-ignored-dirs '("build"))

;;   (defun xref-js2--root-dir ()
;;     "Return the root directory of the project."
;;     (or (rh-project-get-root)
;;         (ignore-errors
;;           (projectile-project-root))
;;         (ignore-errors
;;           (vc-root-dir))
;;         (user-error "You are not in a project")))

;;   :ensure t)

;; /b/} xref-js2

;; /b/{ moz-minor-mode

;; (use-package moz
;;   :commands moz-minor-mode
;;   :interpreter ("moz" . moz-minor-mode)
;;   :ensure t)

;; /b/} moz-minor-mode

;; /b/{ moz-minor-mode

;; (use-package smex
;;   :config
;;   (setq smex-save-file vr-smex-save-file)

;;   :demand t
;;   :ensure t)

;; (require 'smex)
;; (smex-initialize)

;; /b/} moz-minor-mode
