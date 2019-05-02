;;; js-interaction.el --- Minor Node.JS Interaction Mode and Minimalist Node.JS REPL
;;
;; Description: Execute JavaScript commands in Node.JS
;;              directly from JavaScript buffers.
;; Author: Victor Rybynok
;; Copyright (C) 2019, Victor Rybynok, all rights reserved.

(defgroup js-interaction nil
  "Node.js REPL and its minor interaction mode."
  :prefix "jsi-"
  :group 'processes)

(defvar js-interaction-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory where this elisp module is located.")

(defcustom jsi-transpiler #'jsi-transpiler-get-default
  "Specifies what transpiler should be used by js-interaction modes."
  :group 'js-interaction
  :type '(choice (const
                  :tag "Do not use transpiler"
                  nil)
                 (const
                  :tag "Use babel as transpiler"
                  babel)
                 (const
                  :tag "Default function to auto-select transplier"
                  jsi-transpiler-get-default)
                 (function
                  :tag "Function that returns transplier type symbol"
                  :value jsi-transpiler-get-default)))

(defcustom jsi-transpiler-babel-default-modes '(typescript-mode)
  "List of major modes for which babel transpiler should be used by default."
  :group 'js-interaction
  :type '(repeat symbol))

(defun jsi-transpiler-get-default ()
  "Returns `babel' for major-mode equal `typescript-mode'
and nil for other modes."
  (cond
   ((seq-contains-p jsi-transpiler-babel-default-modes major-mode) 'babel)))

;; -------------------------------------------------------------------
;;; js-interaction common functions
;; -------------------------------------------------------------------
;; /b/{

(defun jsi--get-value (var)
  "Returns (funcall var) if `var' is a function or `var' if not."
  (if (functionp var) (funcall var) var))

;; /b/}

;; -------------------------------------------------------------------
;;; Babel transplier for js-interaction modes
;; -------------------------------------------------------------------
;; /b/{

;; (setq-local ts-expr "const x: string = \"xxx\"")

;; /home/rh/projects/s600-solution/wtx/web/
(defcustom jsi-babel-run-directory #'jsi-babel-run-directory-get-default
  "The directory from where Babel is executed.

Possible values are:
 - function which returns string with directory path.
 - string literal with directory path."
  :group 'js-interaction
  :type '(choice (const
                  :tag "Default function to auto-select babel run directory"
                  jsi-babel-run-directory-get-default)
                 (const
                  :tag "Function that returns transpiler type"
                  jsi-transpiler-get-default)))

(defun jsi-babel-run-directory-get-default ()
  "Returns current buffer file directory or `default-directory'
if current buffer has no file."
  (or (ignore-errors (file-name-directory (buffer-file-name)))
      default-directory))

(defcustom jsi-babel-command #'jsi-babel-command-get-default
  "Command used to run Babel.

Possible values are:
 - function which returns string with babel command.
 - string literal with babel command."
  :group 'js-interaction
  :type 'string)

(defvar-local jsi-babel-command-default-cache nil)
(defun jsi-babel-command-get-default ()
  "Returns \"npx --no-install babel\" or \"babel\" if any of those commands
work, or nil otherwise. On first call the returned value is cached in
buffer-local variable `jsi-babel-command-default-cache'.  All consequential
calls would return the cached value."
  (or
   jsi-babel-command-default-cache
   (setq
    jsi-babel-command-default-cache
    (let ((default-directory (jsi--get-value jsi-babel-run-directory)))
      (cond
       ((eq 0 (ignore-errors
                (call-process "npx" nil nil nil
                              "--no-install" "babel" "--version")))
        "npx --no-install babel")
       ((eq 0 (ignore-errors
                (call-process "babel" nil nil nil "--version")))
        "babel"))))))

;; /home/rh/projects/s600-solution/wtx/web/jsi-ts.babel.config.js
(defcustom jsi-babel-config-file #'jsi-babel-config-file-get-default
  "Config file used to run Babel."
  :group 'js-interaction
  :type '(choice (const
                  :tag "Do not pass any config file to babel"
                  nil)
                 (const
                  :tag "Default config file selection function"
                  jsi-babel-config-file-get-default)
                 (function
                  :tag "Function that returns string with config file path"
                  :value jsi-babel-config-file-get-default)
                 (string
                  :tag "String literal with config file path"
                  :value "babel.config.js")))

(defun jsi-babel-config-file-get-default ()
  "Returns default jsi-ts.babel.config.js file path if current buffer major mode
is `typescript-mode'. For all other major modes returns default
jsi-ts.babel.config.js file path.

Default babel config files are located in the same directory as this elisp
module file."
  (cond
   ((eq major-mode 'typescript-mode)
    (concat js-interaction-directory "jsi-ts.babel.config.js"))
   (t (concat js-interaction-directory "jsi.babel.config.js"))))

;; (shell-command-to-string "ls")

;; (require 'json)

;; (setq-local
;;  jsi-babel-shell-command
;;  (concat
;;   "set -euo pipefail;"
;;   "cd " jsi-babel-run-directory ";"
;;   "echo \"" (json-encode-string ts-expr) "\""
;;   "|"
;;   jsi-babel-command
;;   " --no-babelrc --config-file " jsi-ts-babel-config-file
;;   " -f stdin.ts"))

;; echo "const x: number = 0"|npx babel --no-babelrc --config-file ./jsi-ts-babel-config-file -f stdin.ts

;; (shell-command-to-string jsi-babel-shell-command)

;; /b/}

;; -------------------------------------------------------------------
;;; Minimalist Node.js REPL for jsi-node minor mode
;; -------------------------------------------------------------------
;; /b/{

(defcustom jsi-node-repl-prompt "> "
  "Node.js REPL prompt used in `jsi-node-repl-mode'"
  :group 'js-interaction
  :type 'string)

(defvar jsi-node-repl-process-name "jsi-node-repl"
  "Process name of Node.js REPL")

(defvar jsi-node-command "node"
  "Command to start Node.JS")

(defcustom jsi-node-repl-start-js
  (concat
   "const repl = require('repl');"
   "const util = require('util');"
   ;; Do not split long lines to fit terminal width.
   ;; emacs should wrap or trim them instead.
   "process.stdout.columns = 0;"
   "process.stdout.rows = 0;"
   "process.stdout.on('resize', () => {"
   "  if(process.stdout.columns != 0) process.stdout.columns = 0;"
   "  if(process.stdout.rows != 0) process.stdout.rows = 0;"
   "});"
   "repl.start({"
   "  prompt: '" jsi-node-repl-prompt "',"
   "  useGlobal: false,"
   "  replMode: repl.REPL_MODE_SLOPPY,"
   "  writer: output => util.inspect(output, { maxArrayLength: null }),"
   ;; "  writer: output => output,"
   "})")
  "JavaScript expression used to start Node.js REPL"
  :group 'js-interaction
  :type 'string)

(defun jsi-node--strip-all-ascii-escapes (string)
  "Strip ASCII Terminal Escape Sequences"
  ;; \x1b is ^[ - RET ESCAPE
  ;; \x0d is ^M - RET CARRIAGE RETURN
  (replace-regexp-in-string "\x1b\\[[0-9;]*[a-zA-Z]\\|\x0d" "" string))

(defun jsi-node--dedup-prompt (string)
  "Deduplicate string with prompt"
  (let* ((p jsi-node-repl-prompt)
         (regexp (concat p "\\(.*\\)\\(" p "\\1\\)+")))
    (replace-regexp-in-string regexp "\\2" string)))

(defun jsi-node--comint-preoutput-filter (output)
  (setq output (jsi-node--strip-all-ascii-escapes output))
  (setq output (jsi-node--dedup-prompt output))
  (if (and (string-match-p (concat "^" jsi-node-repl-prompt) output)
           (string-match-p (concat "^" (regexp-quote output))
                           (buffer-substring-no-properties
                            (line-beginning-position)
                            (line-end-position))))
      ""
    output))

(defun jsi-node--wait-for-prompt (process)
  (with-current-buffer (process-buffer process)
    (let* ((buffer (current-buffer))
           (last-line (jsi-node--get-buffer-last-line buffer))
           (prompt-regex (concat "^" jsi-node-repl-prompt)))
      (while (not (string-match-p prompt-regex last-line))
        (unless (process-live-p process)
          (error "Node.js REPL process terminated"))
        (accept-process-output nil 0.01)
        (setq last-line (jsi-node--get-buffer-last-line buffer)))
      (goto-char (point-max)))))

(define-derived-mode jsi-node-repl-mode comint-mode "Node.js REPL"
  "Major mode for Node.js REPL"
  (add-hook 'comint-preoutput-filter-functions
            #'jsi-node--comint-preoutput-filter nil t)

  (setq-local comint-process-echoes t)
  (setq-local comint-prompt-regexp (concat "^" jsi-node-repl-prompt))
  (setq-local comint-use-prompt-regexp t)

  (add-hook 'completion-at-point-functions
            #'jsi-node--completion-at-point-function nil t))

(defun jsi-node--set-process-window-size (orig-fun process height width)
  (if (string= (process-name process) jsi-node-repl-process-name)
      (funcall orig-fun process 0 0)
    (funcall orig-fun process height width)))

(advice-add 'set-process-window-size :around
            #'jsi-node--set-process-window-size)

;;;###autoload
(defun jsi-node-repl (&optional bury)
  "Run Node.js REPL"
  (interactive)
  (let ((process (get-process jsi-node-repl-process-name))
        buffer)
    (if process
        (setq buffer (process-buffer process))
      (setq buffer (make-comint
                    jsi-node-repl-process-name
                    jsi-node-command nil "-e" jsi-node-repl-start-js))
      (with-current-buffer buffer (jsi-node-repl-mode))
      (setq process (get-buffer-process buffer))
      (jsi-node--wait-for-prompt process))
    (if bury
        (bury-buffer buffer)
      (pop-to-buffer buffer))
    process))

(defun jsi-node-repl-exit ()
  "Exit Node.js REPL"
  (interactive)
  (let ((process (get-process jsi-node-repl-process-name)))
    (when process
      (with-current-buffer (process-buffer process)
        (insert ".exit")
        (comint-send-input)
        (current-buffer))
      (message "Process %s finished" jsi-node-repl-process-name))))

;;; Minimalist Node.js REPL for inter-repl minor mode
;; /b/}

;; -------------------------------------------------------------------
;;; do-java-script and tab-completions in Node.js REPL
;; -------------------------------------------------------------------
;; /b/{

;; Shamelessly stolen from nodejs-repl-clear-line
(defun jsi-node--clear-process-input (process)
  "Send ^U (NEGATIVE ACKNOWLEDGEMENT) to Node.js process."
  (process-send-string process "\x15"))

(defun jsi-node--get-buffer-last-line (buffer)
  (let ((inhibit-field-text-motion t))
    (save-excursion
      (set-buffer buffer)
      (goto-char (point-max))
      (buffer-substring-no-properties
       (line-beginning-position)
       (line-end-position)))))

(defun jsi-node--send-to-process-filter (process string)
  (with-current-buffer (process-buffer process)
    (goto-char (process-mark process))
    (insert (jsi-node--comint-preoutput-filter string))
    (set-marker (process-mark process) (point))
    ;; Update window-point point - only useful for debugging.
    (dolist (window (get-buffer-window-list))
      (set-window-point window (point)))))

(defun jsi-node--get-java-script-output (input-string)
  (unless (string-empty-p input-string)
    (let (beg end)
      (save-excursion
        (goto-char (point-min))
        (search-forward
         "// Entering editor mode (^D to finish, ^C to cancel)\n" nil t)
        (setq beg (search-forward input-string nil t))
        (setq beg (or (and beg (1+ beg)) (point)))
        (goto-char (point-max))
        (setq end (1- (line-beginning-position)))
        (buffer-substring-no-properties beg end)))))

(defun jsi-node-do-java-script-sync (string)
  "Send string to Node.js process and return the output synchronously"
  (let* ((process (get-process jsi-node-repl-process-name))
         (marker-position-orig (marker-position (process-mark process)))
         (process-filter-orig (process-filter process))
         (process-buffer-orig (process-buffer process))
         ;; \x04 is ^D - END OF TRANSMISSION
         (input (concat ".editor\n" string "\x04")))
    (with-temp-buffer
    ;; (with-current-buffer "dbg"
      (unwind-protect
          (progn
            (set-process-buffer process (current-buffer))
            (set-process-filter
             process #'jsi-node--send-to-process-filter)
            (set-marker (process-mark process) (point-max))
            (process-send-string process input)
            (jsi-node--wait-for-prompt process))
        (set-process-buffer process process-buffer-orig)
        (set-process-filter process process-filter-orig)
        (set-marker (process-mark process)
                    marker-position-orig process-buffer-orig))
      (jsi-node--get-java-script-output string))))

(defun jsi-node--get-tab-completions-output (input-string)
  (let (beg end output-string candidates candidate prefix-length)
    (save-excursion
      (goto-char (point-min))
      (move-beginning-of-line 2)
      (setq beg (point))
      (goto-char (point-max))
      (move-beginning-of-line 1)
      (unless (= (point) (point-min)) (left-char))
      (setq end (point))
      (setq output-string (buffer-substring-no-properties beg end))

      (setq candidates (split-string output-string "[\r\n]+"))
      ;; E.g. "Array." is a prefix in "Array.length" string
      (save-match-data
        (setq candidate (car candidates))
        (string-match "^\\(.+\\.\\)[^[:blank:][:cntrl:]\\.]+" candidate)
        (setq prefix-length (length (match-string 1 candidate))))

      (nreverse
       (seq-reduce
        (lambda (result candidate)
          (if (string-empty-p candidate)
              result
            (push (substring candidate prefix-length) result)))
        candidates ())))))

(defun jsi-node-get-tab-completions-sync (string)
  "Get Node.js REPL tab-completions"
  (let* ((process (get-process jsi-node-repl-process-name))
         (marker-position-orig (marker-position (process-mark process)))
         (process-filter-orig (process-filter process))
         (process-buffer-orig (process-buffer process)))
    (with-temp-buffer
    ;; (with-current-buffer "dbg"
      (unwind-protect
          (progn
            (set-process-buffer process (current-buffer))
            (set-process-filter
             process #'jsi-node--send-to-process-filter)
            (set-marker (process-mark process) (point-min))
            (jsi-node--clear-process-input process)
            (jsi-node--wait-for-prompt process)
            (process-send-string process (concat string "\t"))
            (while (accept-process-output process 0.01))
            (process-send-string process "\t")
            (while (accept-process-output process 0.01))
            (jsi-node--clear-process-input process)
            (jsi-node--wait-for-prompt process))
        (set-process-buffer process process-buffer-orig)
        (set-process-filter process process-filter-orig)
        (set-marker (process-mark process)
                    marker-position-orig process-buffer-orig))
      (jsi-node--get-tab-completions-output string))))

;;; do-java-script and tab-completions in Node.js REPL
;; /b/}

;; -------------------------------------------------------------------
;;; jsi-node-mode - minor Node.JS REPL interaction mode
;; -------------------------------------------------------------------
;; /b/{

(defun jsi-node--get-log-buffer ()
  "Returns `jsi-node-log' buffer. Creates one if it does not already exit."
  (let* ((name (concat "*" "jsi-node-log" "*"))
         (buffer (get-buffer name)))
    (or buffer
        (progn
          (setq buffer (get-buffer-create name))
          (with-current-buffer buffer
            (jsi-node-log-mode))
          buffer))))

(defun jsi-node-log ()
  "Displays `jsi-node-log' buffer. Creates one if it does not already exit."
  (interactive)
  (display-buffer (jsi-node--get-log-buffer)))

;;;###autoload
(defun jsi-node-eval-expression (js-expr)
  (interactive "sEval NodeJS: ")
  (message (jsi-node-do-java-script-sync js-expr)))

(defun jsi-node--js2-forward-expression-p ()
  "Returns t if point is looking at \"=\" or \";\" excluding white space."
  (save-excursion
    (js2-forward-sws)
    (or (looking-at "=[^=]*")
        (looking-at "`")
        (looking-at "\\[")
        (looking-at "\\.")
        (looking-at "("))))

(defun jsi-node--js2-forward-expression ()
  "Skip forward to the \"very end\" of sexp. Uses `js2-mode-forward-sexp' to
skip forward unconditionally first time and then while
`jsi-node--js2-mode-forward-sexp-p' returns t."
  (js2-mode-forward-sexp)
  (while (jsi-node--js2-forward-expression-p)
    (js2-mode-forward-sexp)))

(defun jsi-node--js2-expression-at-pos-beg-end (pos)
  (let (beg end)
    (save-excursion
      (goto-char pos)
      (js2-forward-sws)
      (when (looking-at "var\\b\\|let\\b\\|const\\b")
        (right-word)
        (js2-forward-sws))
      (setq beg (point))
      (jsi-node--js2-forward-expression)
      (setq end (point)))
    (cons beg end)))

(defun jsi-node--pos-inside-symbol-p (pos)
  "Returns t if POS is in inside symbol."
  (let ((bounds (bounds-of-thing-at-point 'symbol)))
    (and bounds
         (> pos (car bounds))
         (< pos (cdr bounds)))))

(defun jsi-node--pos-at-bol-p (pos)
  "Returns t if POS is in the beginning of line excluding white space."
  (string-blank-p
   (buffer-substring-no-properties (line-beginning-position) pos)))

(defun jsi-node--expression-at-pos-beg-end (pos)
  (let (bounds)
    (if (eq major-mode 'js2-mode)
        (if (jsi-node--pos-inside-symbol-p pos)
            (setq bounds (bounds-of-thing-at-point 'symbol))
          (setq bounds (jsi-node--js2-expression-at-pos-beg-end pos)))
      (if (jsi-node--pos-at-bol-p pos)
          (setq bounds (cons (line-beginning-position) (line-end-position)))
        (setq bounds (bounds-of-thing-at-point 'symbol))))
    bounds))

(defun jsi-node--eval (beg end)
  (let* ((js-expr (buffer-substring-no-properties beg end))
         (process (get-process jsi-node-repl-process-name)))
    (unless process
      (setq process (jsi-node-repl t)))
    (with-current-buffer (process-buffer process)
      (jsi-node-do-java-script-sync js-expr))))

;;;###autoload
(defun jsi-node-eval (beg &optional end)
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (list (point) nil)))
  (when (null end)
    (let ((bounds (jsi-node--expression-at-pos-beg-end beg)))
      (setq beg (car bounds)
            end (cdr bounds))))
  (let* ((log-buffer (jsi-node--get-log-buffer))
         (input (buffer-substring-no-properties beg end))
         (output (jsi-node--eval beg end)))
    (if current-prefix-arg
        (save-excursion
          (end-of-line)
          (newline)
          (insert output))
      (with-current-buffer log-buffer
        (goto-char (point-max))
        (insert (concat "// ["  (current-time-string) "] /b/{ js\n\n"))
        (insert input)
        (insert "\n\n")
        (insert "// /b/= node\n\n")
        (insert output)
        (insert "\n\n")
        (insert "// /b/}\n\n"))
      (unless (get-buffer-window log-buffer 'visible)
        (message output))))
  (unless (use-region-p)
    (pulse-momentary-highlight-region beg end 'next-error)))

;;;###autoload
(defun jsi-node-eval-buffer ()
  (interactive)
  (message (jsi-node--eval (point-min) (point-max))))

(defvar jsi-node-mode-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<f5>") #'jsi-node-eval)
    (define-key map (kbd "S-<f5>") #'jsi-node-eval-expression)
    (define-key map (kbd "C-<f5>") #'jsi-node-eval-buffer)
    map))

;;;###autoload
(define-minor-mode jsi-node-mode
  "Minor mode for interacting with NodeJS from other (e.g js) buffers."
  :lighter " jsi-node"
  :keymap jsi-node-mode-keymap
  (if jsi-node-mode
      (progn
        (jsi-node-repl t)
        (add-hook 'completion-at-point-functions
                  'jsi-node--completion-at-point-function nil t))
    (remove-hook 'completion-at-point-functions
                 'jsi-node--completion-at-point-function t)))

(define-derived-mode jsi-node-log-mode fundamental-mode "jsi-node-log"
  "Major mode for jsi-node log."
  :lighter " jsi-node-log"
  ;; (setq-local buffer-read-only t)
  (setq-local window-point-insertion-type t))

;;; jsi-node-mode
;; /b/}

;; -------------------------------------------------------------------
;;; Node.JS REPL completion functions
;; -------------------------------------------------------------------
;; /b/{

(defun jsi-node--extract-completion-input (raw-input)
  ;; Strip '// ... \n' - style comments
  (setq raw-input
        (replace-regexp-in-string "//.*$" "" raw-input))
  ;; Replace all control and white space characters with a single space
  (setq raw-input
        (replace-regexp-in-string "[[:blank:][:cntrl:]]+" " " raw-input))
  ;; Strip '/* ... */' - style comments
  (setq raw-input
        (replace-regexp-in-string "/\\*.*\\*/" "" raw-input))
  ;; Replace multiple space sequences with single space
  (setq raw-input
        (replace-regexp-in-string " +" " " raw-input))
  (setq raw-input (string-trim-left raw-input))
  ;; Remove spaces around '.' operator
  (setq raw-input (replace-regexp-in-string " ?\\. ?" "." raw-input))
  ;; get last valid JavaScript symbol
  (substring raw-input (string-match-p "[[:alnum:]_\\$\\.]*$" raw-input)))

(defun jsi-node--extract-completion-prefix (input)
  (substring input (string-match-p "[^\\.]*$" input)))

(defun jsi-node--get-completion-raw-input ()
  (let ((regex "[^[:alnum:][:blank:][:cntrl:]_/\\*\\$\\.]")
        end)
    (save-excursion
      (setq end (point))
      (if (fboundp 'js--re-search-backward)
          (js--re-search-backward regex)
        (search-backward-regexp regex))
      (buffer-substring-no-properties (point) end))))

(defun jsi-node--in-string-p ()
  "Returns t if point is inside string
see http://ergoemacs.org/emacs/elisp_determine_cursor_inside_string_or_comment.html"
  (nth 3 (syntax-ppss)))

(defun jsi-node--in-comment-p ()
  "Returns t if point is inside comment
see http://ergoemacs.org/emacs/elisp_determine_cursor_inside_string_or_comment.html"
  (nth 4 (syntax-ppss)))

(defun jsi-node--completion-at-point-function ()
  (let (input)
    (if (eq major-mode 'jsi-node-repl-mode)
        (when (comint-after-pmark-p)
          (setq input (buffer-substring-no-properties
                       (comint-line-beginning-position)
                       (point))))
      (unless (or (jsi-node--in-string-p) (jsi-node--in-comment-p))
        (setq input (jsi-node--get-completion-raw-input))))
    (when input
      (setq input (jsi-node--extract-completion-input input))
      (list (- (point) (length (jsi-node--extract-completion-prefix input)))
            (point)
            (jsi-node-get-tab-completions-sync input)))))

;; ;;;###autoload
;; (defun company-tide (command &optional arg &rest ignored)
;;   (interactive (list 'interactive))
;;   (cl-case command
;;     (interactive (company-begin-backend 'company-tide))
;;     (prefix (and
;;              (bound-and-true-p tide-mode)
;;              (-any-p #'derived-mode-p tide-supported-modes)
;;              (tide-current-server)
;;              (not (nth 4 (syntax-ppss)))
;;              (or (tide-completion-prefix) 'stop)))
;;     (candidates (cons :async
;;                       (lambda (cb)
;;                         (tide-command:completions arg cb))))
;;     (sorted t)
;;     (ignore-case tide-completion-ignore-case)
;;     (meta (tide-completion-meta arg))
;;     (annotation (tide-completion-annotation arg))
;;     (doc-buffer (tide-completion-doc-buffer arg))
;;     (post-completion (tide-post-completion arg))))

;; (eval-after-load 'company
;;   '(progn
;;      (cl-pushnew 'company-tide company-backends)))

;;; auto-completion functions
;; /b/}

(provide 'js-interaction)
