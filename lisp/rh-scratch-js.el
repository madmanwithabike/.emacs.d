;;; ramblehead's rh-scratch-js mode

(require 'nodejs-repl)
(require 'js2-mode)

;;;###autoload
(defun rh-scratch-js ()
  (interactive)
  (display-buffer
   (let ((bufp (get-buffer "*rh-scratch-js*"))
         buf)
     (if bufp
         (setq buf bufp)
       (setq buf (get-buffer-create "*rh-scratch-js*")))
     (with-current-buffer buf
       (js2-mode)
       (rh-nodejs-interaction 1)
       (set (make-local-variable 'js2-strict-missing-semi-warning) nil)
       (unless bufp
         (insert "// This buffer is for text that is not saved, and for JavaScript evaluation.\n\n")))
     buf)
   '(display-buffer-same-window)))

(provide 'rh-scratch-js)
