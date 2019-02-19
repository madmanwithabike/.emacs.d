;;; ramblehead's js2-mode configuration

(defvar-local rh-js2-additional-externs '())

;; see http://emacswiki.org/emacs/Js2Mode After js2 has parsed a js file, we
;; look for jslint globals decl comment ("/* global Fred, _, Harry */") and
;; add any symbols to a buffer-local var of acceptable global vars Note that
;; we also support the "symbol: true" way of specifying names via a hack
;; (remove any ":true" to make it look like a plain decl, and any ':false' are
;; left behind so they'll effectively be ignored as you can't have a symbol
;; called "someName:false"
(add-hook
 'js2-post-parse-callbacks
 (lambda ()
   (when (> (buffer-size) 0)
     (let ((btext (replace-regexp-in-string
                   ": *true" " "
                   (replace-regexp-in-string
                    "[\n\t ]+"
                    " "
                    (buffer-substring-no-properties 1 (buffer-size))
                    t t))))
       (mapc (apply-partially 'add-to-list 'js2-additional-externs)
             (append
              rh-js2-additional-externs
              (split-string
               (if (string-match
                    "/\\* *global *\\(.*?\\) *\\*/" btext)
                   (match-string-no-properties 1 btext) "")
               " *, *" t)))))))

(provide 'config-js2-mode)
