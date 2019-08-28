;;; js-interaction.el --- Minor Node.JS Interaction Mode and Minimalist Node.JS REPL
;;
;; Description: Execute JavaScript commands in Node.JS directly from JavaScript
;;              buffers with optional transpilation.
;; Author: Victor Rybynok
;; Copyright (C) 2019, Victor Rybynok, all rights reserved.

;; ------------------------------------------------------------------
;;; Bugs, TODO and R&D
;; ------------------------------------------------------------------
;; /b/{

;; TODO:
;;  [ ] When node output has no errors, colour it with TypeScript mode.
;;  [ ] Add syntax highlight expression results displayed in minibuffer.
;;  [ ] When interacting with JS REPL from jsi-node minor mode, there should be
;;      the maximum minibuffer height after which the output is not displayed in
;;      minibuffer. Instead, it should pop jsi-log buffer and scroll it to its
;;      bottom.
;;  [ ] Add code-blocks "tab-folding" to jsi-log.
;;  [ ] Add skewer as alternative JS REPL jsi-node minor mode.
;;  [ ] Implement scratch repository for pure Node.JS.
;;  [ ] Implement scratch repository for Node.JS with Typescript.
;;  [ ] Implement scratch repository for pure Skewer.
;;  [ ] Implement scratch repository for Skewer with React.
;;  [ ] Implement scratch repository for Skewer with Typescript and React.
;;
;; R&D:
;;  [?] Should jsi-log use pretty-print on Node.JS and Skewer outputs when there
;;      are no errors?
;;  [?] Should jsi-log have inspector-like folding on JS Objects and Array which
;;      nest beyond certain threshold?
;;  [?] Should jsi-log use Emacs' compilation mode to format Node.JS output in
;;      case of errors?

;; /b/}

;; -------------------------------------------------------------------
;;; js-interaction common
;; -------------------------------------------------------------------
;; /b/{

(require 'cl-lib)
(require 'js)
(require 'typescript-mode)

(defgroup js-interaction nil
  "Node.js REPL and its minor interaction mode."
  :prefix "jsi-"
  :group 'processes)

(defun jsi--get (var)
  "Returns (funcall `VAR') if `VAR' is a function or `VAR' if not."
  (if (functionp var) (funcall var) var))

;; /b/}

;; -------------------------------------------------------------------
;;; Transpilers common
;; -------------------------------------------------------------------
;; /b/{

(defcustom jsi-transpiler-babel-default-modes '(typescript-mode)
  "List of major modes for which Babel transpiler should be selected by default.

see `jsi-transpiler-get-default'"
  :group 'js-interaction
  :type '(repeat symbol))

(defcustom jsi-transpiler #'jsi-transpiler-get-default
  "Specifies what transpiler should be used by js-interaction modes."
  :group 'js-interaction
  :type '(choice (const
                  :tag "Do not use transpiler"
                  nil)
                 (const
                  :tag "Use Babel as transpiler"
                  babel)
                 (const
                  :tag "Default function to auto-select transplier"
                  jsi-transpiler-get-default)
                 (function
                  :tag "Function that returns transplier type symbol"
                  :value jsi-transpiler-get-default)))

(defun jsi-transpiler-get-default ()
  "Returns `babel' for major-mode equal `typescript-mode'
and nil for other modes.

This function may recognise more JavsScript-targeted languages and transpilers
in the future."
  (cond
   ;; TODO: Change to seq-contains-p in the future when
   ;;       more emacs'es support it:
   ;; ((seq-contains-p jsi-transpiler-babel-default-modes major-mode) 'babel)))
   ((member major-mode jsi-transpiler-babel-default-modes) 'babel)))

(defcustom jsi-input-language #'jsi-input-language-get-default
  "Recognised input languages."
  :group 'js-interaction
  :type '(choice (const
                  :tag "TypeScript"
                  'ts)
                 (const
                  :tag "JavaScript"
                  'js)
                 (const
                  :tag "Default function to auto-select input language"
                  jsi-input-language-get-default)
                 (function
                  :tag "Function that returns input language"
                  :value jsi-input-language-get-default)))

(defun jsi-input-language-get-default ()
  "Returns input language name abbreviation based on current buffer major mode.
If mode is not recognised, assumes JavaScript."
  (case major-mode
    (typescript-mode 'ts)
    (otherwise 'js)))

;;;###autoload
(defun jsi-transpile-expression (input)
  (interactive "sTranspile expression: ")
  (let ((transpiler (jsi--get jsi-transpiler)))
    (if (null transpiler)
        (error "`jsi-transpiler' is evaluated to nil.")
      (let* ((log-buffer (jsi--log-get-buffer))
             (transpiler-output (jsi-transpile-sync transpiler input)))
        (jsi-log-record-add
         (jsi--get jsi-input-language) input
         transpiler transpiler-output
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
         transpiler-output)
    (setq input (string-trim input))
    (if (null transpiler)
        (error "`jsi-transpiler' is evaluated to nil.")
      (setq transpiler-output (jsi-transpile-sync transpiler input)))
    (jsi-log-record-add
     (jsi--get jsi-input-language) input
     transpiler transpiler-output
     nil nil)
    (unless (get-buffer-window log-buffer 'visible)
      (message (plist-get transpiler-output ':text))))
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

;; TODO: Fix code-blocks to ignore e.g. /b/ { in strings

;; (defun jsi-log-add-record
;;     (input-language input transpiler transpiler-output output)
;;   (with-current-buffer log-buffer
;;     (let ((inhibit-read-only t))
;;       (goto-char (point-max))
;;       (insert (concat "// ["  (current-time-string) "] /b/{ "
;;                       input-language "\n\n"))
;;       (insert input)
;;       (insert "\n\n")
;;       (when transpiler
;;         (insert "// /b/> " (symbol-name transpiler) "\n\n")
;;         (insert transpiler-output)
;;         (insert "\n\n"))
;;       (insert "// /b/> node\n\n")
;;       (insert output)
;;       (insert "\n\n")
;;       (insert "// /b/}\n\n"))))

(defun jsi--log-fontify-string (string mode)
  "Return STR fontified according to MODE."
  (with-temp-buffer
    (insert string)
    (when mode
      (delay-mode-hooks (funcall mode))
      (font-lock-default-function mode)
      (font-lock-default-fontify-region
       (point-min) (point-max) nil))
    (buffer-string)))

(defun jsi--log-fontify-major-mode (syntax)
  "Return mode used to fontify SYNTAX."
  (case syntax
    (ts 'typescript-mode)
    (js 'typescript-mode)
    ;; (js 'js-mode)
    (output nil)))

(defun jsi--log-symbol-text (symbol)
  (case symbol
    ('js "JavaScript")
    ('ts "TypeScript")
    ('babel "Babel")
    ('node "Node.js")))

(defun jsi-log-record-add (input-language input
                           transpiler transpiler-output
                           interpreter interpreter-output)
  (with-current-buffer (jsi--log-get-buffer)
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert
       (propertize (concat "@ " (jsi--log-symbol-text input-language)
                           " Input \n")
                   'face 'jsi-log-record-heading-highlight))
      (insert (jsi--log-fontify-string
               input (jsi--log-fontify-major-mode input-language)))
      (insert "\n\n")
      (when transpiler
        (insert
         (propertize (concat "> " (jsi--log-symbol-text transpiler)
                             " Output \n")
                     'face 'jsi-log-transpiler-heading-highlight))
        (insert (jsi--log-fontify-string
                 (plist-get transpiler-output ':text)
                 (if (null (plist-get transpiler-output ':error))
                     (jsi--log-fontify-major-mode 'js)
                   (jsi--log-fontify-major-mode 'output))))
        (insert "\n\n"))
      (when interpreter
        (insert
         (propertize (concat "> " (jsi--log-symbol-text interpreter)
                             " Output \n")
                     'face 'jsi-log-interpreter-heading-highlight))
        (insert (jsi--log-fontify-string
                 interpreter-output (jsi--log-fontify-major-mode 'output)))
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
                  :tag "Default function to auto-select Babel run directory"
                  jsi-babel-run-directory-get-default)
                 (string
                  :tag "String literal with Babel run directory"
                  :value "~")
                 (const
                  :tag "Function that returns string with Babel run directory"
                  jsi-babel-run-directory-get-default)))

;; (defvar jsi-babel-skip-import nil
;;   "Expressions beginning with 'import' keyword skip transpiler (e.g. babel) and
;; passed directly to interpreter (e.g. node).

;; This might be useful when 'import' is handled outside babel
;; (e.g. 'esm', see https://github.com/standard-things/esm),
;; and 'import' elission should not occur
;; (e.g. see https://github.com/Microsoft/TypeScript/wiki/FAQ#why-are-imports-being-elided-in-my-emit.")

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

(defun jsi--babel-imports-only-p (input-string)
  "Returns t if INPUT-STRING contains 'import' statements only."
  (with-temp-buffer
    (delay-mode-hooks (js-mode))
    (insert input-string)
    (goto-char (point-min))
    (let ((import-only t))
      (while (and import-only (not (eobp)))
        (js--forward-syntactic-ws)
        (when (looking-at ";")
          (forward-char)
          (js--forward-syntactic-ws))
        (unless (eobp)
          (if (looking-at "import")
              (jsi--dwim-js--forward-expression)
            (setq import-only nil))))
      import-only)))

(defun jsi-babel-transpile-sync (input-string)
  "Transpile STRING with Babel and magic."
  (if (jsi--babel-imports-only-p input-string)
  ;; (if (and jsi-babel-skip-import
  ;;          (jsi--babel-imports-only-p input-string))
      `(:text ,input-string
        :error nil)

    (let ((babel-command (jsi--get jsi-babel-command))
          arg-string output-string output-error exit-code)
      (if (null babel-command)
          (error "jsi-babel: Babel command not found.")
        (setq input-string
              (replace-regexp-in-string "[\\]" "\\\\\\\\" input-string))
        (setq input-string
              (replace-regexp-in-string "\"" "\\\\\"" input-string))
        (setq input-string
              (replace-regexp-in-string "`" "\\\\`" input-string))
        (setq input-string
              (replace-regexp-in-string "\\$" "\\\\$" input-string))

        ;; TODO: Remove the following await hiding logic once Babel can handle
        ;;       it. see https://github.com/babel/babel/issues/9329
        ;;
        ;; "Hide" await keyword from Babel input-string
        (setq input-string
              (replace-regexp-in-string
               "^\\([[:blank:]]*\\)await\\([[:blank:]\n\r]\\)"
               "\\1/* __await_out__ */\\2" input-string))
        (setq input-string
              (replace-regexp-in-string
               "^\\(.*\\)await\\([[:blank:]\n\r]\\)"
               "\\1/* __await_in__ */\\2" input-string))

        (setq
         arg-string
         (concat
          "set -euo pipefail;"
          "cd " (jsi--get jsi-babel-run-directory) ";"
          "set +e;"
          "echo \"" input-string "\""
          "|"
          (jsi--get jsi-babel-command)
          " --no-babelrc "
          (let ((config-file (jsi--get jsi-babel-config-file)))
            (if config-file (concat "--config-file " config-file) ""))
          " -f stdin.ts; echo $?"))
        (setq
         output-string
         (string-trim
          (with-temp-buffer
            ;; TODO: Instead of `shell-command' and script in arg-string
            ;;       it can be `call-process' and Node.JS script. This should
            ;;       make js-interaction more friendly to some sub-standard OSs.
            (shell-command arg-string t)
            (goto-char (point-max))
            (move-beginning-of-line 0)
            (setq exit-code
                  (string-to-number (buffer-substring-no-properties
                                     (point) (line-end-position))))
            (delete-region (point) (line-end-position))
            (buffer-string))))
        (if (= exit-code 0)
            (setq output-error nil)
          (setq output-error 'transpiler))

        ;; TODO: Remove the following await hiding logic once Babel can handle
        ;;       it. see https://github.com/babel/babel/issues/9329
        ;;
        ;; Get await keyword back to Babel output-string.
        (setq output-string
              (replace-regexp-in-string
               "/\\* __await_out__ \\*/[\n\r]+"
               "await " output-string))
        (setq output-string
              (replace-regexp-in-string
               "[\n\r]*/\\* __await_in__ \\*/[\n\r]+"
               " await " output-string))

        `(:text ,output-string
          :error ,output-error)))))

(defun jsi-transpile-sync (transpiler string)
  "Transpile STRING using TRANSPILER.
Only `babel' TRANSPILER value is currently supported."
  (case transpiler
    (babel (jsi-babel-transpile-sync string))
    (otherwise
     (error (concat "jsi: provided TRANSPILER value is not supported")))))

;; /b/}

;; -------------------------------------------------------------------
;;; jsi-node-repl - minimalist Node.JS REPL for jsi-node minor mode
;; -------------------------------------------------------------------
;; /b/{

;; (defvar jsi-node-command "node"
;;   "Command to start Node.JS")

(defcustom jsi-node-command "node"
  "Command to start Node.JS"
  :group 'js-interaction
  :type '(choice (string
                  :tag "String literal with Node.JS command"
                  :value "node")
                 (const
                  :tag "Function that returns string with Node.JS command")))

(defcustom jsi-node-repl-prompt "> "
  "Node.js REPL prompt used in `jsi-node-repl-mode'"
  :group 'js-interaction
  :type 'string)

(defcustom jsi-node-repl-compact-output "2"
  "Compact argument: 'util.inspect(output, { `compact': false, })'"
  :group 'js-interaction
  :type 'string)

(defvar jsi-node-repl-process-name "jsi-node-repl"
  "Process name of Node.js REPL")

(defvar jsi-node-command-require-esm nil
  "Allowes to use ES6 modules in modern Node.JS without mjs and with full
commonjs compatibility.
see https://github.com/standard-things/esm")

(defvar jsi-node-command-arguments
  '("--experimental-repl-await"
    "--throw-deprecation" ;; Mainly for UnhandledPromiseRejectionWarning
    "--abort-on-uncaught-exception")
  "List of node command arguments (switches) used to start Node.JS")

(defcustom jsi-node-repl-start-js
  (concat
   ;; ;; see https://github.com/standard-things/esm
   ;; "require('esm');"
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
   "  writer: output => util.inspect(output, {"
   "    maxArrayLength: Infinity,"
   "    depth: Infinity,"
   "    compact: " jsi-node-repl-compact-output ","
   "  }),"
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
        buffer arguments)
    (if process
        (setq buffer (process-buffer process))
      ;; TODO: convert to seq-copy and seq-concatenate in the future
      ;;       when more emacs'es support it:
      (setq arguments (copy-sequence jsi-node-command-arguments))
      (when jsi-node-command-require-esm
        (setq arguments (append '("-r" "esm") arguments)))
      (setq buffer (eval
                    `(make-comint
                      jsi-node-repl-process-name
                      ,(jsi--get jsi-node-command) nil
                      ,@arguments
                      "-e" jsi-node-repl-start-js)))
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
  (if (string-blank-p input-string)
      ""
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
;;; Auxiliary Do What I Mean (DWIM) functions
;; -------------------------------------------------------------------
;; /b/{

;; Looks like I should write to js-mode maintainers too...
;; see https://github.com/emacs-typescript/typescript.el/issues/105
(defun jsi--dwim-js--forward-expression ()
  "Move forward over a whole JavaScript expression."
  (cl-loop
   do
   (forward-comment most-positive-fixnum)
   (cl-loop
    until (or (eolp)
              (progn
                (forward-comment most-positive-fixnum)
                (memq (char-after) '(?\, ?\; ?\] ?\) ?\}))))
    do (forward-sexp))

   while (and (eq (char-after) ?\n)
              (save-excursion
                (forward-char)
                (js--continued-expression-p)))))

(defun jsi--dwim-js-expression-at-pos-beg-end (pos)
  "This function works only in js-mode and derived modes, such as js2-mode.
It tries to guess the JavaScript expression following POS which user
wants to evaluate.

Return value is (BEG . END) of expression at POS."
  (let (beg end)
    (save-excursion
      (goto-char pos)
      (js--forward-syntactic-ws)
      (when (looking-at "var\\b\\|let\\b\\|const\\b")
        (right-word)
        (js--forward-syntactic-ws))
      (setq beg (point))
      (jsi--dwim-js--forward-expression)
      (setq end (point)))
    (cons beg end)))

(defun jsi--dwim-ts-expression-at-pos-beg-end (pos)
  "This function works only in typescript-mode. It tries to guess the TypeScript
expression following POS which user wants to evaluate.

Return value is an expression begging and end cons (BEG . END)"
  (let (beg end)
    (save-excursion
      (goto-char pos)
      (typescript--forward-syntactic-ws)
      (when (looking-at "var\\b\\|let\\b\\|const\\b")
        (right-word)
        (typescript--forward-syntactic-ws))
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
  "Returns t if POS is in the beginning of line neglecting white space."
  (string-blank-p
   (buffer-substring-no-properties (line-beginning-position) pos)))

(defun jsi--dwim-expression-at-pos-beg-end (pos)
  "This function may call an appropriate jsi--dwim-... function depending on
POS surrounding text and current major mode:
 * when POS is inside symbol, return bounds (BEG . END) for that symbol;
 * at typescript-mode, call `jsi--dwim-ts-expression-at-pos-beg-end';
 * at js-mode and its derived modes, call
   `jsi--dwim-js-expression-at-pos-beg-end';
 * for all other major modes, if point is at the beginning of the line
   neglecting white space, return bounds of that line.

Return value is an expression begging and end cons (BEG . END)"
  (let (bounds)
    (cond
     ((derived-mode-p 'js-mode)
      (if (jsi--dwim-pos-inside-symbol-p pos)
          (setq bounds (bounds-of-thing-at-point 'symbol))
        (setq bounds (jsi--dwim-js-expression-at-pos-beg-end pos))))
     ((eq major-mode 'typescript-mode)
      (if (jsi--dwim-pos-inside-symbol-p pos)
          (setq bounds (bounds-of-thing-at-point 'symbol))
        (setq bounds (jsi--dwim-ts-expression-at-pos-beg-end pos))))
     (t
      (if (jsi--dwim-pos-at-bol-p pos)
          (setq bounds (cons (line-beginning-position) (line-end-position)))
        (setq bounds (bounds-of-thing-at-point 'symbol)))))
    bounds))

;; /b/}

;; -------------------------------------------------------------------
;;; jsi-node-mode - minor js-interaction mode for jsi-node-repl
;; -------------------------------------------------------------------
;; /b/{

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
         transpiler-output output)
    (setq input (string-trim input))
    (if (null transpiler)
        (setq output (jsi--node-eval input))
      (setq transpiler-output (jsi-transpile-sync transpiler input))
      (when (null (plist-get transpiler-output ':error))
        (setq output (jsi--node-eval (plist-get transpiler-output ':text)))))
    (if current-prefix-arg
        (save-excursion
          (end-of-line)
          (newline)
          (if (null (plist-get transpiler-output ':error))
              (insert output)
            (insert (plist-get transpiler-output ':text))))
      (if (null (plist-get transpiler-output ':error))
          (jsi-log-record-add
           (jsi--get jsi-input-language) input
           transpiler transpiler-output
           'node output)
        (jsi-log-record-add
         (jsi--get jsi-input-language) input
         transpiler transpiler-output
         nil nil))
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
