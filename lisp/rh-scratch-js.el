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
       (rh-nodejs-repl-interaction 1)
       (setq-local js2-strict-missing-semi-warning nil)
       (unless bufp
         (run-with-timer
          0 nil
          (lambda (buf)
            (when buf
              (with-current-buffer buf
                (insert
                 (concat "// This buffer is for text that is not saved, "
                         "and for JavaScript evaluation.\n\n")))))
          buf)))
     buf)
   '(display-buffer-same-window)))



(provide 'rh-scratch-js)
