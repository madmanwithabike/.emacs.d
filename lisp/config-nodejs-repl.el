;;; ramblehead's nodejs-repl configuration

(defvar rh-nodejs-repl-interaction-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<f5>") #'rh-nodejs-repl-send-line-or-region)
    map))

(define-minor-mode rh-nodejs-repl-interaction
  "Minor mode for interacting with a nodejs from other (e.g js) buffers."
  :lighter " NodeJS Interaction"
  :keymap rh-nodejs-repl-interaction-map
  (when rh-nodejs-repl-interaction
    (let ((win (selected-window)))
      (nodejs-repl-switch-to-repl)
      (select-window win))))

(defadvice nodejs-repl-switch-to-repl
    (around rh-nodejs-repl-switch-to-repl () activate)
  (let ((buf (get-buffer "*nodejs*")))
    (if buf
        (pop-to-buffer buf)
      (nodejs-repl))))

(defun rh-nodejs-repl-send-line-or-region (start end)
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (list (point) (point))))
  (let ((win (frame-selected-window)))
    (nodejs-repl-switch-to-repl)
    (select-window win)
    (if (/= start end)
        (nodejs-repl-send-region start end)
      (if (eq (point) (line-beginning-position))
          (nodejs-repl-send-line)
        (nodejs-repl-send-last-expression)))))

;; (defun nodejs-repl--completion-at-point-function ()
;;   (setq nodejs-repl-completion-at-point-called-p t)
;;   (when (or (comint-after-pmark-p)
;;             rh-nodejs-repl-interaction)
;;     (let* ((input (buffer-substring (comint-line-beginning-position) (point)))
;;            require-arg
;;            token-length
;;            file-completion-p)
;;       (setq nodejs-repl-get-completions-for-require-p nil)  ;; reset
;;       (if (not (nodejs-repl--in-string-p))
;;           (setq token-length (length (nodejs-repl--get-last-token input)))
;;         (setq require-arg (nodejs-repl--extract-require-argument input)
;;               nodejs-repl-get-completions-for-require-p t)
;;         (if (and require-arg
;;                  (or (= (length require-arg) 1)  ; only quote or double quote
;;                      (not (string-match-p "[./]" (substring require-arg 1 2)))))  ; not file path
;;             (setq token-length (1- (length require-arg)))
;;           (let ((quote-pos (save-excursion
;;                              (search-backward-regexp "['\"]" (point-at-bol) t)
;;                              (forward-char)
;;                              (point))))
;;             (when quote-pos
;;               (setq file-completion-p t
;;                     token-length (- (point) quote-pos))))))
;;       (when token-length
;;         (list
;;          (save-excursion (backward-char token-length) (point))
;;          (point)
;;          (if file-completion-p
;;              #'completion-file-name-table
;;            (completion-table-dynamic #'nodejs-repl--get-completions)))))))

(provide 'config-nodejs-repl)
