;; temporarily increase GC cap -> less GC calls -> faster startup
(setq gc-cons-threshold (* 200 1024 1024))
(defun my/lower-gc-threshold () (setq gc-cons-threshold (* 16 1024 1024)))
(add-hook 'emacs-startup-hook #'my/lower-gc-threshold)

(defun my/frame-close ()
  ((when (null (frame-list))
    ((garbage-collect)
    (dolist (buffer (buffer-list))
      (unless (or (eq buffer (current-buffer))
                  (buffer-file-name buffer)
                  (buffer-modified-p buffer))
        (kill-buffer buffer)))
    (garbage-collect)))
   ))
(add-hook 'after-delete-frame-functions #'my/frame-close)

;; install use-package if it doesn't exist
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(defun reload-config ()
  (interactive)
  (load-file user-init-file))

;; Reload config when init.el is saved
(add-hook 'after-save-hook
  (lambda ()
    (when (string= (buffer-file-name) user-init-file)
    (reload-config))))

(setq inhibit-startup-screen t) ; no startup screen
(global-display-line-numbers-mode 1) ; line numbers
;; (setq truncate-lines t)
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(setq ring-bell-function 'ignore)
(setq backup-directory-alist `(("." . "~/.config/emacs/backups")))

;; @font
(set-face-attribute 'default nil :height 120)
;(set-frame-font "Miracode-12" nil t)
(add-to-list 'default-frame-alist '(font . "Miracode-12"))

;; package manager setup
(require 'package)
(setq package-archives '(
  ("gnu"   . "https://elpa.gnu.org/packages/")
  ("melpa" . "https://melpa.org/packages/")))

(setq package-enable-at-startup nil)
(unless (bound-and-true-p package--initialized)
  (package-initialize))

(eval-when-compile (require 'use-package))
(setq use-package-always-ensure t)

(use-package benchmark-init
  :config
  (benchmark-init/activate)
  (add-hook 'after-init-hook 'benchmark-init/deactivate))

;; autoselect the most recent window
(defun my/select-new-window (original-fun &rest args)
  (let ((window (apply original-fun args)))
    (when window
      (select-window window))
    window))
(advice-add 'display-buffer :around #'my/select-new-window)

(use-package which-key
  :init (which-key-mode 1))

(use-package undo-tree
  :init
  (global-undo-tree-mode 1)  ; Enable globally
  :config
  (setq undo-tree-visualizer-timestamps t)  ; Show timestamps in visualizer
  (setq undo-tree-auto-save-history nil))   ; Disable auto-saving undo history

(use-package evil
  :init (evil-mode 1)
  :config
    (setq
      evil-emacs-state-modes nil
      evil-insert-state-modes nil
      evil-motion-state-modes nil
      evil-default-state 'normal
      evil-disable-insert-state-buffers nil
      evil-read-only-buffers nil)
    (evil-define-key 'normal 'global 
      (kbd "g c") 'comment-line))

;; i think this is broken???
(setq evil-undo-system 'undo-redo)

(setq
  evil-undo-function #'undo-tree-undo
  evil-redo-function #'undo-tree-redo)

(use-package catppuccin-theme
  :config (setq catppuccin-flavor 'mocha) (load-theme 'catppuccin t))

;; @lsp
(use-package lsp-mode
  :init
  (setq lsp-keymap-prefix "C-c l")
  :hook (
    (zig-mode . lsp))
  :commands lsp)

(use-package company
  :config 
  (global-company-mode t) ; Enable company-mode globally
  (setq company-idle-delay 0.2 ; Show suggestions after 0.2 seconds of typing
    company-minimum-prefix-length 1 ; Start showing suggestions after 1 character
    company-tooltip-limit 10 ; Show up to 10 suggestions in the dropdown
    company-show-numbers t ; Show numbers for quick selection
    company-tooltip-align-annotations t ; Align annotations (e.g., type information) properly
    company-dabbrev-downcase nil)) ; Don't lowercase completions

(use-package zig-mode :defer t :mode "\\.zig\\'"
  :config
  (setq zig-format-on-save nil))
(use-package lua-mode :defer t :mode "\\.lua\\'")
(use-package nix-mode :defer t :mode "\\.nix\\'")
(use-package markdown-mode :defer t :mode "\\.md\\'")

(use-package lsp-ui
  :after lsp-mode
  :hook (lsp-mode . lsp-ui-mode)
  :config
  (setq
    lsp-ui-doc-enable t
    lsp-ui-sideline-enable t
    lsp-ui-peek-enable t))

;; @looks
(use-package all-the-icons
  :if (display-graphic-p))  ; Only load in GUI mode

(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :config
  (setq
    doom-modeline-height 25      ; Set mode-line height
    doom-modeline-bar-width 5    ; Set bar width
    doom-modeline-buffer-file-name-style 'relative-from-project))  ; Show relative file paths

(use-package ligature :config
  (ligature-set-ligatures 'prog-mode '("->" "=>" "==" "!=" "<=" ">=" "NOTE:" "TODO:"))
  (global-ligature-mode t))

(use-package ivy
  :config
  (ivy-mode 1)
  (setq
    ivy-use-virtual-buffers t
    ivy-count-format "(%d/%d) "))

(use-package counsel)

(use-package general)
(general-create-definer my-leader-def
  :states 'normal
  :prefix "SPC")
(my-leader-def
  :keymaps 'override
  ;; File operations
  "f f" 'counsel-find-file       ; Open file
  "f r" 'counsel-recentf         ; Open recent file
  "f s" 'save-buffer             ; Save file
  "f d" 'delete-file             ; Delete file

  ;; Buffer operations
  "b b" 'ivy-switch-buffer       ; Switch buffer
  "b k" 'kill-buffer             ; Kill buffer
  "b n" 'next-buffer             ; Next buffer
  "b p" 'previous-buffer         ; Previous buffer

  ;; Project operations
  "p f" 'counsel-projectile-find-file  ; Find file in project
  "p p" 'projectile-switch-project     ; Switch project

  ;; Other
  "h f" 'describe-function       ; Describe function
  "h v" 'describe-variable       ; Describe variable
  "h k" 'describe-key            ; Describe keybinding
  "q q" 'save-buffers-kill-emacs ; Quit Emacs

  "c c" 'compile
)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(display-line-numbers-type 'visual)
 '(package-selected-packages '(nix-mode lua-mode undo-tree evil which-key)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
