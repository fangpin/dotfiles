;;; packages.el --- irony layer packages file for Spacemacs.
;;
;; Copyright (c) 2012-2017 Sylvain Benner & Contributors
;;
;; Author: fangpin <fangpin@lab>
;; URL: https://github.com/syl20bnr/spacemacs
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

;;; Commentary:

;; See the Spacemacs documentation and FAQs for instructions on how to implement
;; a new layer:
;;
;;   SPC h SPC layers RET
;;
;;
;; Briefly, each package to be installed or configured by this layer should be
;; added to `irony-packages'. Then, for each package PACKAGE:
;;
;; - If PACKAGE is not referenced by any other Spacemacs layer, define a
;;   function `irony/init-PACKAGE' to load and initialize the package.

;; - Otherwise, PACKAGE is already referenced by another Spacemacs layer, so
;;   define the functions `irony/pre-init-PACKAGE' and/or
;;   `irony/post-init-PACKAGE' to customize the package as it is loaded.

;;; Code:

(defconst irony-packages
  '(company-irony
    company-irony-c-headers
    irony
    irony-eldoc
    flycheck-irony)
  "The list of Lisp packages required by the irony layer.

Each entry is either:

1. A symbol, which is interpreted as a package to be installed, or

2. A list of the form (PACKAGE KEYS...), where PACKAGE is the
    name of the package to be installed or loaded, and KEYS are
    any number of keyword-value-pairs.

    The following keys are accepted:

    - :excluded (t or nil): Prevent the package from being loaded
      if value is non-nil

    - :location: Specify a custom installation location.
      The following values are legal:

      - The symbol `elpa' (default) means PACKAGE will be
        installed using the Emacs package manager.

      - The symbol `local' directs Spacemacs to load the file at
        `./local/PACKAGE/PACKAGE.el'

      - A list beginning with the symbol `recipe' is a melpa
        recipe.  See: https://github.com/milkypostman/melpa#recipe-format")

(defun irony/init-irony ()
  (use-package irony
    :defer t
    :commands (irony-mode irony-install-server)
    :init
    (progn
      (add-hook 'c-mode-hook 'irony-mode)
      (add-hook 'c++-mode-hook 'irony-mode))
    :config
    (progn
      (setq irony-user-dir (f-slash (f-join user-home-directory "bin" "irony")))
      (setq irony-server-install-prefix irony-user-dir)
      (setq irony-cdb-search-directory-list "~/repos/")
      (add-hook 'c++-mode-hook (lambda () (setq irony-additional-clang-options '("-std=c++11"))))
      (defun irony/irony-mode-hook ()
        (define-key irony-mode-map [remap completion-at-point] 'irony-completion-at-point-async)
        (define-key irony-mode-map [remap complete-symbol] 'irony-completion-at-point-async))

      (add-hook 'irony-mode-hook 'irony/irony-mode-hook)
      (add-hook 'irony-mode-hook 'irony-cdb-autosetup-compile-options))))

(when (configuration-layer/layer-usedp 'auto-completion)
  (defun irony/init-company-irony ()
    (use-package company-irony
      :if (configuration-layer/package-usedp 'company)
      :defer t
      :commands company-irony
      :init
      (progn
        (push 'company-irony company-backends-c-mode-common)
        (add-hook 'irony-mode-hook 'company-irony-setup-begin-commands))
      )))

(when (configuration-layer/layer-usedp 'auto-completion)
  (defun irony/init-company-irony-c-headers ()
    (use-package company-irony-c-headers
      :if (configuration-layer/package-usedp 'company)
      :defer t
      :commands company-irony-c-headers
      :init
      (push 'company-irony-c-headers company-backends-c-mode-common))))

(when (configuration-layer/layer-usedp 'syntax-checking)
  (defun irony/init-flycheck-irony ()
    (use-package flycheck-irony
      :if (configuration-layer/package-usedp 'flycheck)
      :defer t
      :init (add-hook 'irony-mode-hook 'flycheck-irony-setup))))

(defun irony/init-irony-eldoc ()
  (use-package irony-eldoc
    :commands (irony-eldoc)
    :init
    (add-hook 'irony-mode-hook 'irony-eldoc)))

;;; packages.el ends here
