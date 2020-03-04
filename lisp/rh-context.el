;;; rh-context.el --- set of functions to work with buffers rh-context
;;
;; Description: Finding rh-context to which buffers belong.
;; Author: Victor Rybynok
;; Copyright (C) 2019, Victor Rybynok, all rights reserved.

;; -------------------------------------------------------------------
;;; rh-context implementation
;; -------------------------------------------------------------------
;; /b/{

(defvar rh-context-changed-hook nil
  "List of hook functions that are called by `rh-context-select' after
rh-context changed.")

(defvar rh-context-current "any"
  "RH-BS-CONTEXT-CURRENT can be either:
* rh-context string id to only show buffers from that rh-context;
* \"any\" symbol to show all buffers regardless of their rh-context.
* \"none\" to only show buffers with no rh-context;")

(defvar rh-context-dir-name ".rh-context")

(defvar rh-context-window-config-alist nil)

(defun rh-context-show-buffer-p (buffer)
  (if (string= rh-context-current "any")
      t
    (let ((buffer-contexts (rh-context-get-buffer-contexts buffer)))
      (if (null buffer-contexts)
          (if (string= rh-context-current "none") t nil)
        (member rh-context-current buffer-contexts)))))

(defun rh--context-completing-read (prompt)
  (let ((available-contexts
         (append '("any" "none")
                 (rh-context-get-available-contexts)))
        (completion-ignore-case  t)
        read-result)
    (list (completing-read
           prompt
           available-contexts
           nil t nil nil
           rh-context-current))))

(defun rh-context-select (context)
  (interactive (rh--context-completing-read
                "Select rh-context: "))
  (unless (string= rh-context-current context)
    (setq rh-context-current context)
    (run-hooks 'rh-context-changed-hook)
    (message "Selected rh-context: %s" rh-context-current)))

(defun rh-context-window-config-save (&optional context)
  (interactive (rh--context-completing-read
                "Save window configuration for rh-context: "))
  (when (null context) (setq context rh-context-current))
  (let* ((prev-context-window-config
          (assoc context rh-context-window-config-alist #'string=))
         (new-window-config (current-window-configuration))
         (new-context-window-config (cons context new-window-config)))
    (if prev-context-window-config
        (setf (cdr prev-context-window-config) new-window-config)
      (push new-context-window-config rh-context-window-config-alist))
    (message "Saved window configuration for rh-context: %s" context)
    new-context-window-config))

(defun rh-context-window-config-restore (&optional context)
  (interactive (rh--context-completing-read
                "Restore window configuration for rh-context: "))
  (when (null context) (setq context rh-context-current))
  (let ((context-window-config
         (assoc context rh-context-window-config-alist #'string=)))
    (if context-window-config
        (progn
          (set-window-configuration (cdr context-window-config))
          (message "Restored window configuration for rh-context: %s" context)
          context-window-config)
      (message "No window configuration found for rh-context: %s" context)
      nil)))

(defun rh-context-window-config-switch (context)
  (interactive (rh--context-completing-read
                "Switch window configuration and rh-context: "))
  (unless (string= context rh-context-current)
    (rh-context-window-config-save rh-context-current)
    (rh-context-select context)
    (rh-context-window-config-restore context)))

(defun rh-context-compute-buffer-contexts (buffer-or-name)
  (let* ((buffer-path (with-current-buffer buffer-or-name
                        ;; (or buffer-file-name default-directory)
                        (or buffer-file-name
                            (if (or (eq major-mode 'compilation-mode)
                                    (eq major-mode 'shell-mode)
                                    (eq major-mode 'jsi-node-repl-mode)
                                    (eq major-mode 'jsi-log-mode)
                                    (string-match-p
                                     "^magit-" (symbol-name major-mode)))
                                default-directory
                              "/"))
                        ))
         (context-dir (locate-dominating-file
                       (file-name-as-directory buffer-path)
                       rh-context-dir-name))
         context-dir-symlinks contexts)
    (when context-dir
      (setq context-dir
            (file-name-as-directory
             (concat context-dir rh-context-dir-name)))
      (setq context-dir-symlinks
            (seq-filter
             #'file-symlink-p
             (when (file-directory-p context-dir)
               (directory-files context-dir t nil t))))
      (when context-dir-symlinks
        (setq contexts
              (seq-map
               (lambda (symlink)
                 (abbreviate-file-name (file-chase-links symlink)))
               context-dir-symlinks)))
      (add-to-list
       'contexts
       (directory-file-name
        (abbreviate-file-name
         (file-chase-links
          (file-name-directory (directory-file-name context-dir)))))
       t #'string=)
      contexts)))

(defun rh-context-update-all-buffers-contexts ()
  (interactive)
  (let ((buffers (buffer-list)))
    (seq-do
     (lambda (buffer)
       (with-current-buffer buffer
         (setq-local rh-context-buffer-contexts
                     (rh-context-compute-buffer-contexts buffer))))
     buffers))
  (message "Updated all buffers contexts."))

(defun rh-context-get-buffer-contexts (buffer-or-name)
  (with-current-buffer buffer-or-name
    (if (local-variable-p 'rh-context-buffer-contexts)
        rh-context-buffer-contexts
      (setq-local rh-context-buffer-contexts
                  (rh-context-compute-buffer-contexts buffer-or-name)))))

(defun rh-context-get-available-contexts ()
  (let ((buffers (buffer-list)))
    (seq-reduce
     (lambda (contexts buffer)
       (let ((buffer-contexts (rh-context-get-buffer-contexts buffer)))
         (when buffer-contexts
           (dolist (buffer-context buffer-contexts)
             (add-to-list 'contexts buffer-context t)))
         contexts))
     buffers '())))

;; /b/}

(provide 'rh-context)
