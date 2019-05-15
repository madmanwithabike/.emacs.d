;;; js-interaction.el --- Minor Node.JS Interaction Mode and Minimalist Node.JS REPL
;;
;; Description: Execute JavaScript commands in Node.JS
;;              directly from JavaScript buffers.
;; Author: Victor Rybynok
;; Copyright (C) 2019, Victor Rybynok, all rights reserved.

;; -------------------------------------------------------------------
;;; js-interaction common
;; -------------------------------------------------------------------
;; /b/{

(defgroup js-interaction nil
  "Node.js REPL and its minor interaction mode."
  :prefix "jsi-"
  :group 'processes)

(defun jsi--get (var)
  "Returns (funcall var) if `var' is a function or `var' if not."
  (if (functionp var) (funcall var) var))

;; /b/}

;; -------------------------------------------------------------------
;;; Transpilers common
;; -------------------------------------------------------------------
;; /b/{

(defcustom jsi-transpiler-babel-default-modes '(typescript-mode)
  "List of major modes for which babel transpiler should be used by default."
  :group 'js-interaction
  :type '(repeat symbol))

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

(defun jsi-transpiler-get-default ()
  "Returns `babel' for major-mode equal `typescript-mode'
and nil for other modes."
  (cond
   ;; TODO: Change to seq-contains-p in the future when more emacs'es support it
   ;; ((seq-contains-p jsi-transpiler-babel-default-modes major-mode) 'babel)))
   ((member major-mode jsi-transpiler-babel-default-modes) 'babel)))

(defcustom jsi-input-language #'jsi-input-language-get-default
  "String with input language name abbreviation used in interaction logs."
  :group 'js-interaction
  :type '(choice (const
                  :tag "Language name abbreviation string"
                  'ts)
                 (const
                  :tag "Language name abbreviation string"
                  'js)
                 (const
                  :tag "Default function to auto-select language abbreviation"
                  jsi-transpiler-get-default)
                 (function
                  :tag "Function that returns language abbreviation string"
                  :value jsi-transpiler-get-default)))

(defun jsi-input-language-get-default ()
  "Returns input language name abbreviation based on current buffer major mode.
If mode is not recognised, assumes JavaScript."
  (case major-mode
    (typescript-mode 'ts)
    (otherwise 'js)))

;;;###autoload
(defun jsi-transpile-expression (js-expr)
  (interactive "sTranspile expression: ")
  (let ((transpiler (jsi--get jsi-transpiler)))
    (if (null transpiler)
        (error "`jsi-transpiler' is evaluated to nil.")
      (let* ((log-buffer (jsi--log-get-buffer))
             (input js-expr)
             (transpiled-input (jsi-transpile-sync transpiler input)))
        (jsi-log-record-add
         (jsi--get jsi-input-language) input
         transpiler transpiled-input
         nil nil)
        (unless (get-buffer-window log-buffer 'visible)
          (message output))))))

;;;###autoload
(defun jsi-transpile (beg &optional end no-pulse)
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (list (point) nil)))
  (when (null end)
    (let ((bounds (jsi--dwim-expression-at-pos-beg-end beg)))
      (setq beg (car bounds)
            end (cdr bounds))))
  (let* ((log-buffer (jsi--log-get-buffer))
         (input-language (symbol-name (jsi--get jsi-input-language)))
         (input (buffer-substring-no-properties beg end))
         (transpiler (jsi--get jsi-transpiler))
         transpiled-input)
    (setq input (string-trim input))
    (if (null transpiler)
        (error "`jsi-transpiler' is evaluated to nil.")
      (setq transpiled-input (jsi-transpile-sync transpiler input)))
    (jsi-log-record-add
     (jsi--get jsi-input-language) input
     transpiler transpiled-input
     nil nil)
    (unless (get-buffer-window log-buffer 'visible)
      (message transpiled-input)))
  (unless (or no-pulse (use-region-p))
    (pulse-momentary-highlight-region beg end 'next-error)))

;;;###autoload
(defun jsi-transpile-buffer ()
  (interactive)
  (jsi-transpile (point-min) (point-max) t))

;; /b/}

;; -------------------------------------------------------------------
;;; jsi-log - js-interaction modes log
;; -------------------------------------------------------------------
;; /b/{

(defface jsi-log-record-heading-highlight
  '((((class color) (background light))
     :background "grey75"
     :foreground "grey30"
     :weight bold)
    (((class color) (background dark))
     :background "grey35"
     :foreground "grey70"
     :weight bold))
  "Face for log record heading."
  :group 'js-interaction)

(defface jsi-log-transpiler-heading-highlight
  '((((class color) (background light))
     :background "#ffffcc"
     :foreground "#aaaa11"
     :weight bold)
    (((class color) (background dark))
     :background "#555522"
     :foreground "#ffffcc"
     :weight bold))
  "Face for log transpiler heading."
  :group 'js-interaction)

(defface jsi-log-interpreter-heading-highlight
  '((((class color) (background light))
     :background "#cceecc"
     :foreground "#22aa22"
     :weight bold)
    (((class color) (background dark))
     :background "#336633"
     :foreground "#cceecc"
     :weight bold))
  "Face for log interpreter heading."
  :group 'js-interaction)

;; (face-spec-set
;;  'jsi-log-interpreter-heading-highlight
;;  '((((class color) (background light))
;;     :background "#cceecc"
;;     :foreground "#22aa22")
;;    (((class color) (background dark))
;;     :background "#336633"
;;     :foreground "#cceecc"))
;;  'face-defface-spec)

(define-derived-mode
  jsi-log-mode fundamental-mode "jsi-log"
  "Major mode for js-interaction modes log."
  ;; :lighter " js-interaction"
  (setq-local buffer-read-only t)
  (setq-local window-point-insertion-type t))

;; TODO Fix code-blocks to ignore e.g. /b/ { in strings

;; (defun jsi-log-add-record
;;     (input-language input transpiler transpiled-input output)
;;   (with-current-buffer log-buffer
;;     (let ((inhibit-read-only t))
;;       (goto-char (point-max))
;;       (insert (concat "// ["  (current-time-string) "] /b/{ "
;;                       input-language "\n\n"))
;;       (insert input)
;;       (insert "\n\n")
;;       (when transpiler
;;         (insert "// /b/> " (symbol-name transpiler) "\n\n")
;;         (insert transpiled-input)
;;         (insert "\n\n"))
;;       (insert "// /b/> node\n\n")
;;       (insert output)
;;       (insert "\n\n")
;;       (insert "// /b/}\n\n"))))

(defun jsi--log-fontify-string (string mode)
  "Return STR fontified according to MODE."
  (with-temp-buffer
    (insert string)
    (delay-mode-hooks (funcall mode))
    (font-lock-default-function mode)
    (font-lock-default-fontify-region
     (point-min) (point-max) nil)
    (buffer-string)))

(defun jsi--log-fontify-mode (language)
  "Return mode used to fontify LANGUAGE."
  (case language
    (ts 'typescript-mode)
    (js 'js-mode)))

(defun jsi--log-symbol-text (symbol)
  (case symbol
    ('js "JavaScript")
    ('ts "TypeScript")
    ('babel "Babel")
    ('node "Node.js")))

(defun jsi-log-record-add (input-language input
                           transpiler transpiled-input
                           interpreter output)
  (with-current-buffer (jsi--log-get-buffer)
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert
       (propertize (concat "@ " (jsi--log-symbol-text input-language) "\n")
                   'face 'jsi-log-record-heading-highlight))
      (insert (jsi--log-fontify-string
               input (jsi--log-fontify-mode input-language)))
      (insert "\n\n")
      (when transpiler
        (insert
         (propertize (concat "> " (jsi--log-symbol-text transpiler) "\n")
                     'face 'jsi-log-transpiler-heading-highlight))
        (insert (jsi--log-fontify-string
                 transpiled-input (jsi--log-fontify-mode 'js)))
        (insert "\n\n"))
      (when interpreter
        (insert
         (propertize (concat "> " (jsi--log-symbol-text interpreter) "\n")
                     'face 'jsi-log-interpreter-heading-highlight))
        (insert (jsi--log-fontify-string
                 output (jsi--log-fontify-mode 'js)))
        (insert "\n\n")))))

(defun jsi--log-get-buffer ()
  "Returns `jsi-log' buffer. Creates one if it doesn't already exit."
  (let* ((name "*jsi-log*")
         (buffer (get-buffer name)))
    (or buffer
        (progn
          (setq buffer (get-buffer-create name))
          (with-current-buffer buffer
            (jsi-log-mode))
          buffer))))

(defun jsi-log ()
  "Displays `jsi-log' buffer. Creates one if it doesn't already exit."
  (interactive)
  (display-buffer (jsi--log-get-buffer)))

;; /b/}

;; -------------------------------------------------------------------
;;; Babel transplier for js-interaction modes
;; -------------------------------------------------------------------
;; /b/{

(defcustom jsi-babel-run-directory #'jsi-babel-run-directory-get-default
  "The directory from where Babel is executed."
  :group 'js-interaction
  :type '(choice (const
                  :tag "Default function to auto-select babel run directory"
                  jsi-babel-run-directory-get-default)
                 (string
                  :tag "String literal with babel run directory"
                  :value "~")
                 (const
                  :tag "Function that returns string with babel run directory"
                  jsi-babel-run-directory-get-default)))

(defun jsi-babel-run-directory-get-default ()
  "Returns current buffer file directory or `default-directory'
if current buffer has no file."
  (or (ignore-errors (file-name-directory (buffer-file-name)))
      default-directory))

(defcustom jsi-babel-command #'jsi-babel-command-get-default
  "Command used to run Babel."
  :group 'js-interaction
  :type '(choice (const
                  :tag "Default function to auto-select babel command"
                  jsi-babel-command-get-default)
                 (string
                  :tag "String literal with babel command"
                  :value "babel")
                 (const
                  :tag "Function that returns string with babel command"
                  jsi-babel-command-get-default)))

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
    (let ((default-directory (jsi--get jsi-babel-run-directory)))
      (cond
       ((eq 0 (ignore-errors
                (call-process "npx" nil nil nil
                              "--no-install" "babel" "--version")))
        "npx --no-install babel")
       ((eq 0 (ignore-errors
                (call-process "babel" nil nil nil "--version")))
        "babel"))))))

(defcustom jsi-babel-config-file #'jsi-babel-config-file-get-default
  "Config file used to run Babel."
  :group 'js-interaction
  :type '(choice (const
                  :tag "Do not pass any config file to Babel"
                  nil)
                 (const
                  :tag "Default function to auto-select Babel config file"
                  jsi-babel-config-file-get-default)
                 (function
                  :tag "Function that returns string with Babel config file"
                  :value jsi-babel-config-file-get-default)
                 (string
                  :tag "String literal with config file"
                  :value "babel.config.js")))

(defun jsi--babel-locate-dominating-config (dir file-name)
  "Walk up DIR and find the first parent directory which containes FILE-NAME.
Returns full path of the found file or nil if none was found."
  (let ((dir (locate-dominating-file
              (jsi--get jsi-babel-run-directory)
              (lambda (parent)
                (directory-files parent nil
                                 (concat "^" (regexp-quote file-name) "$"))))))
    (when dir (concat dir file-name))))

(defun jsi-babel-config-file-get-default ()
  "Returns default jsi-ts.babel.config.js file path if current buffer major mode
is `typescript-mode'. For all other major modes returns default
jsi-ts.babel.config.js file path.

Default babel config files are searched by waling up the directory
defined by `jsi-babel-run-directory'."
  (let ((dir (jsi--get jsi-babel-run-directory)))
    (cond
     ((eq major-mode 'typescript-mode)
      (jsi--babel-locate-dominating-config dir "jsi-ts.babel.config.js"))
     (t (jsi--babel-locate-dominating-config dir "jsi.babel.config.js")))))

(defun jsi-babel-transpile-sync (string)
  "Transply STRING with Babel"
  (let ((babel-command (jsi--get jsi-babel-command))
        full-command)
    (if (null babel-command)
        (error "jsi-babel: Babel command not found.")
      (setq string (replace-regexp-in-string "[\\]" "\\\\\\\\" string))
      (setq string (replace-regexp-in-string "\"" "\\\\\"" string))
      (setq
       full-command
       (concat
        "set -euo pipefail;"
        "cd " (jsi--get jsi-babel-run-directory) ";"
        "echo \"" string "\""
        "|"
        (jsi--get jsi-babel-command)
        " --no-babelrc "
        (let ((config-file (jsi--get jsi-babel-config-file)))
          (if config-file (concat "--config-file " config-file) ""))
        " -f stdin.ts"))
      (string-trim (shell-command-to-string full-command)))))

(defun jsi-transpile-sync (transpiler string)
  "Transply STRING using TRANSPILER.
Only `babel' TRANSPILER value is currently supported."
  (case transpiler
    (babel (jsi-babel-transpile-sync string))
    (otherwise
     (error (concat "jsi: provided TRANSPILER value is not supported")))))

;; /b/}

;; -------------------------------------------------------------------
;;; jsi-node-repl - minimalist Node.js REPL for jsi-node minor mode
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

(defun jsi--node-strip-all-ascii-escapes (string)
  "Strip ASCII Terminal Escape Sequences"
  ;; \x1b is ^[ - RET ESCAPE
  ;; \x0d is ^M - RET CARRIAGE RETURN
  (replace-regexp-in-string "\x1b\\[[0-9;]*[a-zA-Z]\\|\x0d" "" string))

(defun jsi--node-dedup-prompt (string)
  "Deduplicate string with prompt"
  (let* ((p jsi-node-repl-prompt)
         (regexp (concat p "\\(.*\\)\\(" p "\\1\\)+")))
    (replace-regexp-in-string regexp "\\2" string)))

(defun jsi--node-comint-preoutput-filter (output)
  (setq output (jsi--node-strip-all-ascii-escapes output))
  (setq output (jsi--node-dedup-prompt output))
  (if (and (string-match-p (concat "^" jsi-node-repl-prompt) output)
           (string-match-p (concat "^" (regexp-quote output))
                           (buffer-substring-no-properties
                            (line-beginning-position)
                            (line-end-position))))
      ""
    output))

(defun jsi--node-wait-for-prompt (process)
  (with-current-buffer (process-buffer process)
    (let* ((buffer (current-buffer))
           (last-line (jsi--node-get-buffer-last-line buffer))
           (prompt-regex (concat "^" jsi-node-repl-prompt)))
      (while (not (string-match-p prompt-regex last-line))
        (unless (process-live-p process)
          (error "Node.js REPL process terminated"))
        (accept-process-output nil 0.01)
        (setq last-line (jsi--node-get-buffer-last-line buffer)))
      (goto-char (point-max)))))

(define-derived-mode jsi-node-repl-mode comint-mode "Node.js REPL"
  "Major mode for Node.js REPL"
  (add-hook 'comint-preoutput-filter-functions
            #'jsi--node-comint-preoutput-filter nil t)

  (setq-local comint-process-echoes t)
  (setq-local comint-prompt-regexp (concat "^" jsi-node-repl-prompt))
  (setq-local comint-use-prompt-regexp t)

  (add-hook 'completion-at-point-functions
            #'jsi--node-completion-at-point-function nil t))

(defun jsi--node-set-process-window-size (orig-fun process height width)
  (if (string= (process-name process) jsi-node-repl-process-name)
      (funcall orig-fun process 0 0)
    (funcall orig-fun process height width)))

(advice-add 'set-process-window-size :around
            #'jsi--node-set-process-window-size)

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
      (jsi--node-wait-for-prompt process))
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

;; /b/}

;; -------------------------------------------------------------------
;;; do-java-script and tab-completions for jsi-node-repl
;; -------------------------------------------------------------------
;; /b/{

;; Shamelessly stolen from nodejs-repl-clear-line
(defun jsi--node-clear-process-input (process)
  "Send ^U (NEGATIVE ACKNOWLEDGEMENT) to Node.js process."
  (process-send-string process "\x15"))

(defun jsi--node-get-buffer-last-line (buffer)
  (let ((inhibit-field-text-motion t))
    (save-excursion
      (set-buffer buffer)
      (goto-char (point-max))
      (buffer-substring-no-properties
       (line-beginning-position)
       (line-end-position)))))

(defun jsi--node-send-to-process-filter (process string)
  (with-current-buffer (process-buffer process)
    (goto-char (process-mark process))
    (insert (jsi--node-comint-preoutput-filter string))
    (set-marker (process-mark process) (point))
    ;; Update window-point point - only useful for debugging.
    (dolist (window (get-buffer-window-list))
      (set-window-point window (point)))))

(defun jsi--node-get-java-script-output (input-string)
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
  "Send STRING to Node.js process and return the output synchronously"
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
             process #'jsi--node-send-to-process-filter)
            (set-marker (process-mark process) (point-max))
            (process-send-string process input)
            (jsi--node-wait-for-prompt process))
        (set-process-buffer process process-buffer-orig)
        (set-process-filter process process-filter-orig)
        (set-marker (process-mark process)
                    marker-position-orig process-buffer-orig))
      (jsi--node-get-java-script-output string))))

(defun jsi--node-get-tab-completions-output (input-string)
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
             process #'jsi--node-send-to-process-filter)
            (set-marker (process-mark process) (point-min))
            (jsi--node-clear-process-input process)
            (jsi--node-wait-for-prompt process)
            (process-send-string process (concat string "\t"))
            (while (accept-process-output process 0.01))
            (process-send-string process "\t")
            (while (accept-process-output process 0.01))
            (jsi--node-clear-process-input process)
            (jsi--node-wait-for-prompt process))
        (set-process-buffer process process-buffer-orig)
        (set-process-filter process process-filter-orig)
        (set-marker (process-mark process)
                    marker-position-orig process-buffer-orig))
      (jsi--node-get-tab-completions-output string))))

;; /b/}

;; -------------------------------------------------------------------
;;; jsi-node-mode - minor js-interaction mode for jsi-node-repl
;; -------------------------------------------------------------------
;; /b/{

(defun jsi--dwim-js2-forward-expression-p ()
  "Returns t if point is looking at \"=\" or \";\" excluding white space."
  (save-excursion
    (js2-forward-sws)
    (or (looking-at "=[^=]*")
        (looking-at "`")
        (looking-at "\\[")
        (looking-at "\\.")
        (looking-at "("))))

(defun jsi--dwim-js2-forward-expression ()
  "Skip forward to the \"very end\" of sexp. Uses `js2-mode-forward-sexp' to
skip forward unconditionally first time and then while
`jsi--node-js2-mode-forward-sexp-p' returns t."
  (js2-mode-forward-sexp)
  (while (jsi--dwim-js2-forward-expression-p)
    (js2-mode-forward-sexp)))

(defun jsi--dwim-js2-expression-at-pos-beg-end (pos)
  (let (beg end)
    (save-excursion
      (goto-char pos)
      (js2-forward-sws)
      (when (looking-at "var\\b\\|let\\b\\|const\\b")
        (right-word)
        (js2-forward-sws))
      (setq beg (point))
      (jsi--dwim-js2-forward-expression)
      (setq end (point)))
    (cons beg end)))

(defun jsi--dwim-ts-expression-at-pos-beg-end (pos)
  (let (beg end)
    (save-excursion
      (goto-char pos)
      (typescript--forward-syntactic-ws)
      (setq beg (point))
      (typescript--forward-expression)
      (setq end (point)))
    (cons beg end)))

(defun jsi--dwim-pos-inside-symbol-p (pos)
  "Returns t if POS is in inside symbol."
  (let ((bounds (bounds-of-thing-at-point 'symbol)))
    (and bounds
         (> pos (car bounds))
         (< pos (cdr bounds)))))

(defun jsi--dwim-pos-at-bol-p (pos)
  "Returns t if POS is in the beginning of line excluding white space."
  (string-blank-p
   (buffer-substring-no-properties (line-beginning-position) pos)))

(defun jsi--dwim-expression-at-pos-beg-end (pos)
  (let (bounds)
    (cond
     ((eq major-mode 'js2-mode)
      (if (jsi--dwim-pos-inside-symbol-p pos)
          (setq bounds (bounds-of-thing-at-point 'symbol))
        (setq bounds (jsi--dwim-js2-expression-at-pos-beg-end pos))))
     ((eq major-mode 'typescript-mode)
      (if (jsi--dwim-pos-inside-symbol-p pos)
          (setq bounds (bounds-of-thing-at-point 'symbol))
        (setq bounds (jsi--dwim-ts-expression-at-pos-beg-end pos))))
     (t
      (if (jsi--dwim-pos-at-bol-p pos)
          (setq bounds (cons (line-beginning-position) (line-end-position)))
        (setq bounds (bounds-of-thing-at-point 'symbol)))))
    bounds))

(defun jsi--node-eval (js-expr)
  (let ((process (get-process jsi-node-repl-process-name)))
    (unless process
      (setq process (jsi-node-repl t)))
    (with-current-buffer (process-buffer process)
      (jsi-node-do-java-script-sync js-expr))))

(defun jsi--node-eval-region (beg end)
  (jsi--node-eval (buffer-substring-no-properties beg end)))

;;;###autoload
(defun jsi-node-eval-expression (js-expr)
  (interactive "sEval NodeJS: ")
  (let ((log-buffer (jsi--log-get-buffer))
        (input js-expr)
        (output (jsi-node-do-java-script-sync js-expr)))
    (jsi-log-record-add
     'js input nil nil 'node output)
    (unless (get-buffer-window log-buffer 'visible)
      (message output))))

;;;###autoload
(defun jsi-node-eval (beg &optional end no-pulse)
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (list (point) nil)))
  (when (null end)
    (let ((bounds (jsi--dwim-expression-at-pos-beg-end beg)))
      (setq beg (car bounds)
            end (cdr bounds))))
  (let* ((log-buffer (jsi--log-get-buffer))
         ;; (input-language (symbol-name (jsi--get jsi-input-language)))
         (input (buffer-substring-no-properties beg end))
         (transpiler (jsi--get jsi-transpiler))
         transpiled-input output)
    (setq input (string-trim input))
    (if (null transpiler)
        (setq output (jsi--node-eval input))
      (setq transpiled-input (jsi-transpile-sync transpiler input))
      (setq output (jsi--node-eval transpiled-input)))
    (if current-prefix-arg
        (save-excursion
          (end-of-line)
          (newline)
          (insert output))
      (jsi-log-record-add
       (jsi--get jsi-input-language) input
       transpiler transpiled-input
       'node output)
      (unless (get-buffer-window log-buffer 'visible)
        (message output))))
  (unless (or no-pulse (use-region-p))
    (pulse-momentary-highlight-region beg end 'next-error)))

;;;###autoload
(defun jsi-node-eval-buffer ()
  (interactive)
  (jsi-node-eval (point-min) (point-max) t))

(defvar jsi-node-mode-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<f6>") #'jsi-transpile)
    (define-key map (kbd "S-<f6>") #'jsi-transpile-expression)
    (define-key map (kbd "C-<f6>") #'jsi-transpile-buffer)
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
                  'jsi--node-completion-at-point-function nil t))
    (remove-hook 'completion-at-point-functions
                 'jsi--node-completion-at-point-function t)))

;; /b/}

;; -------------------------------------------------------------------
;;; completion functions for jsi-node-repl
;; -------------------------------------------------------------------
;; /b/{

(defun jsi--node-extract-completion-input (raw-input)
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
  (setq raw-input
        ;; ''. or "". completions as string object
        (if (string-match-p "[\"'] ?\\.$" raw-input)
            "String.name."
          ;; get last valid JavaScript symbol
          (substring raw-input
                     (string-match-p "[[:alnum:]_\\$\\.]*$" raw-input))))
  (if (string-match-p "^ ?\\. ?$" raw-input)
      ;; Return symbol which has no competions to ignore Node.JS REPL dot
      ;; commands when in non-REPL buffers
      "+"
    raw-input))

(defun jsi--node-extract-completion-prefix (input)
  (substring input (string-match-p "[^\\.]*$" input)))

(defun jsi--node-get-completion-raw-input ()
  (let ((regex "[^[:alnum:][:blank:][:cntrl:]_/\\*\\$\\.]")
        end)
    (save-excursion
      (setq end (point))
      (if (fboundp 'js--re-search-backward)
          (js--re-search-backward regex)
        (search-backward-regexp regex))
      (buffer-substring-no-properties (point) end))))

(defun jsi--node-in-string-p ()
  "Returns t if point is inside string
see http://ergoemacs.org/emacs/elisp_determine_cursor_inside_string_or_comment.html"
  (nth 3 (syntax-ppss)))

(defun jsi--node-in-comment-p ()
  "Returns t if point is inside comment
see http://ergoemacs.org/emacs/elisp_determine_cursor_inside_string_or_comment.html"
  (nth 4 (syntax-ppss)))

(defun jsi--node-completion-at-point-function ()
  (let (input)
    (if (eq major-mode 'jsi-node-repl-mode)
        (when (comint-after-pmark-p)
          (setq input (buffer-substring-no-properties
                       (comint-line-beginning-position)
                       (point))))
      (unless (or (jsi--node-in-string-p) (jsi--node-in-comment-p))
        (setq input (jsi--node-get-completion-raw-input))))
    (when input
      (setq input (jsi--node-extract-completion-input input))
      (list (- (point) (length (jsi--node-extract-completion-prefix input)))
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

;; /b/}

(provide 'js-interaction)
