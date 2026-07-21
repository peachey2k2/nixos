;; Trust the current workspace before Helix opens any documents. Calling the
;; :workspace-trust command here is unsafe in this Steelix revision because it
;; also tries to restart an LSP before the editor has created a view.
(require-builtin steel/filesystem as fs::)

(define workspace (find-workspace))
(define data-home
  (with-handler
    (lambda (_) (string-append (env-var "HOME") "/.local/share"))
    (env-var "XDG_DATA_HOME")))
(define helix-data-dir (string-append data-home "/helix"))
(define trust-file (string-append helix-data-dir "/trusted_workspaces"))

(fs::create-directory! helix-data-dir)

(define trusted-workspaces
  (if (fs::path-exists? trust-file)
    (call-with-input-file trust-file read-port-to-string)
    ""))

(unless (member workspace (split-many trusted-workspaces "\n"))
  (call-with-output-file trust-file
    (lambda (port) (display (string-append workspace "\n") port))
    #:exists 'append))
