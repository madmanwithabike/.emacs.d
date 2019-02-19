(require 'windmove)

(defun unfill-paragraph ()
  "Takes a multi-line paragraph and makes it into a single line of text."
  (interactive)
  (let ((fill-column (point-max)))
    (fill-paragraph nil)))

(defun count-words-region (start end)
  "Print and returns number of words in the region."
  (interactive "r")
  (save-excursion
    (let ((n 0))
      (goto-char start)
      (while (< (point) end)
        (if (forward-word 1)
            (setq n (1+ n))))
      (message "Region has %d words" n)
      n)))

(defun word-count-region (start end)
  "Print number of lines words and characters in the region."
  (interactive "r")
  (message "Region has %d lines, %d words, %d characters"
           (count-lines start end)
           (count-words-region start end)
           (- end start)))

(defun latex-word-count ()
  (interactive)
  (shell-command (concat "texcount " "\"" (buffer-file-name) "\"")))

;; http://stackoverflow.com/questions/9288181/converting-from-camelcase-to-in-emacs
(defun toggle-camelcase-underscores ()
  "Toggle between camcelcase and underscore notation for the symbol at point."
  (interactive)
  (save-excursion
    (let* ((bounds (bounds-of-thing-at-point 'symbol))
           (start (car bounds))
           (end (cdr bounds))
           (currently-using-underscores-p
            (progn (goto-char start)
                   (re-search-forward "_" end t))))
      (if currently-using-underscores-p
          (progn
            (upcase-initials-region start end)
            (replace-string "_" "" nil start end)
            (downcase-region start (1+ start)))
        (replace-regexp "\\([A-Z]\\)" "_\\1" nil (1+ start) end)
        (downcase-region start end)))))

(defun insert-file-path-at-point ()
  (interactive)
  (insert (expand-file-name (buffer-file-name))))

(defun insert-file-name-at-point ()
  (interactive)
  (insert (file-name-nondirectory (buffer-file-name))))

(defun downcase-first-letter (obj)
  (concat (downcase (substring obj 0 1)) (substring obj 1)))

(defun wrap-in-quotes-region (start end)
  "Places quotes around each line in the region."
  (interactive "r")
  (save-excursion
    (replace-regexp "^\\(.*\\)$" "\"\\1\"" nil start end)))

(defun unwrap-from-quotes-region (start end)
  "Removes quotes around each line in the region."
  (interactive "r")
  (save-excursion
    (replace-regexp
     "^\\([ \t]*\\)\"\\(.*\\)\"\\([ \t]*\\)$" "\\1\\2\\3"
     nil start end)))

(defun rh-deduce-default-text (&optional remove-shift-selection)
  (if (and (use-region-p)
           ;; Check if region is a "shift selection"
           (eq (car-safe transient-mark-mode) 'only))
      (let (result)
        (setq result (buffer-substring-no-properties
                      (region-beginning) (region-end)))
        (when remove-shift-selection
          (setq mark-active nil))
        result)
    (thing-at-point 'symbol t)))

;; see https://emacs.stackexchange.com/questions/22162/how-to-set-mark-in-elisp-and-have-shift-selection
(defun rh-shift-select-current-line ()
  (interactive)
  (let ((oldval (or (cdr-safe transient-mark-mode) transient-mark-mode)))
    (setq mark-active nil)
    (beginning-of-line)
    (set-mark (point-marker))
    (end-of-line)
    (setq transient-mark-mode (cons 'only oldval))))

;; (defun rh-shift-select-current-line ()
;;   (interactive)
;;   (beginning-of-line)
;;   (setq this-command-keys-shift-translated t)
;;   (call-interactively 'end-of-line))

;; (defun rh-window-for-display-at-direction (direction &optional arg window)
;;   (let ((win (windmove-find-other-window direction arg window)))
;;     (when (and win
;;                ;; Check if win is not dedicated and not side window
;;                (not (window-dedicated-p win))
;;                (null (window-parameter (selected-window) 'window-side)))
;;       win)))

(defun rh-window-for-display-at-direction (direction &optional arg window)
  (let ((win (windmove-find-other-window direction arg window)))
    (when win
      ;; Check if win is not dedicated, not side window and not minibuffer
      (if (or (window-dedicated-p win)
              (window-parameter win 'window-side)
              (window-minibuffer-p win))
          (rh-window-for-display-at-direction direction arg win)
        win))))

(defun rh-display-buffer-reuse-up (buffer alist)
  (let ((win (rh-window-for-display-at-direction 'up)))
    (when win
      (window--display-buffer buffer win 'reuse alist)
      win)))

(defun rh-display-buffer-reuse-down (buffer alist)
  (let ((win (rh-window-for-display-at-direction 'down)))
    (when win
      (window--display-buffer buffer win 'reuse alist)
      win)))

(defun rh-display-buffer-reuse-right (buffer alist)
  (let ((win (rh-window-for-display-at-direction 'right)))
    (when win
      (window--display-buffer buffer win 'reuse alist)
      win)))

(defun rh-display-buffer-reuse-left (buffer alist)
  (let ((win (rh-window-for-display-at-direction 'left)))
    (when win
      (window--display-buffer buffer win 'reuse alist)
      win)))
