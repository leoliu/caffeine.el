;;; caffeine.el --- control Caffeine from emacs      -*- lexical-binding: t; -*-

;; Copyright (C) 2013  Leo Liu

;; Author: Leo Liu <sdl.web@gmail.com>
;; Version: 1.0
;; Keywords: processes, tools
;; Created: 2013-07-30
;; URL: https://github.com/leoliu/caffeine.el

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Caffeine - http://lightheadsw.com/caffeine - is a small app to keep
;; your Mac awake. This package provides a button in the modeline to
;; control Caffeine which can be handy when using emacs in fullscreen
;; mode.
;;
;; This package requires function `do-applescript' to work.

;;; Code:

(defgroup caffeine nil
  "Control Caffeine from Emacs."
  :group 'tools)

(defcustom caffeine-default-duration 3600
  "Default number of seconds to activate Caffeine."
  :type 'integer
  :group 'caffeine)

(defcustom caffeine-mode-line-update-interval 120
  "Number of seconds to run `caffeine-mode-line-update'."
  :type 'integer
  :group 'caffeine)

(defface caffeine-active
  '((t (:inherit font-lock-type-face)))
  "Face to use when Caffeine is activated."
  :group 'caffeine)

(defvar caffeine-active-p nil)

(defun caffeine-mode-line-update ()
  (let ((count (do-applescript "tell application \"System Events\" to \
count (every process whose name is \"Caffeine\")")))
    (setq caffeine-active-p
          ;; NB: COUNT can be nil when `noninteractive' or some odd
          ;; value when compiled.
          (and (stringp count) (> (string-to-number count) 0)
               (equal (do-applescript
                       "tell application \"Caffeine\" to get active")
                      "true")))
    (force-mode-line-update 'all)))

(defun caffeine-toggle ()
  (interactive)
  (do-applescript
   (format "tell application \"Caffeine\"
 if it is active then
  turn off
 else
  turn on for %d
 end if
 active
end tell"
           caffeine-default-duration))
  (caffeine-mode-line-update))

(defvar caffeine-mode-line-map
  (let ((map (make-sparse-keymap))
        (menu (make-sparse-keymap "Activate Caffeine for")))
    (mapc
     (lambda (x)
       (define-key menu (vector (nth 1 x))
         `(menu-item
           ,(car x)
           (lambda ()
             (interactive)
             (do-applescript
              ,(if (nth 2 x)
                   (format "tell application \"Caffeine\" to turn on for %d"
                           (nth 2 x))
                 "tell application \"Caffeine\" to turn on"))
             (caffeine-mode-line-update)))))
     (reverse '(("Indefinitely" caffeine-inf)
                ("15 minutes" caffeine-15min 900)
                ("30 minutes" caffeine-30min 1800)
                ("1 hour" caffeine-1h 3600)
                ("2 hours" caffeine-2h 7200)
                ("5 hours" caffeine-5h 18000))))
    (define-key map [mode-line down-mouse-1] 'caffeine-toggle)
    (define-key map [mode-line down-mouse-3] (cons "Caffeine" menu))
    map))

(defvar caffeine-mode-timer nil)

;;;###autoload
(define-minor-mode caffeine-mode nil nil
  :global t
  ;; This is eval'd frequently so don't put any slow code here.
  ;; Applescripts can be slow.
  :lighter
  (:eval
   (propertize " "
               'face (and caffeine-active-p 'caffeine-active)
               ;; 'mouse-face 'mode-line-highlight
               ;; FIXME: shadowed by mode-line-modes
               'help-echo
               '(progn
                  ;; If Caffeine is turned on/off outside Emacs, the
                  ;; status may be out-of-sync. Update it first.
                  (caffeine-mode-line-update)
                  (concat "Caffeine is " (if caffeine-active-p "on" "off")))
               'keymap caffeine-mode-line-map))
  (when (timerp caffeine-mode-timer)
    (cancel-timer caffeine-mode-timer))
  (setq caffeine-mode-timer nil)
  (when caffeine-mode
    (caffeine-mode-line-update)
    (setq caffeine-mode-timer
          (run-with-idle-timer caffeine-mode-line-update-interval
                               t
                               #'caffeine-mode-line-update))))

(provide 'caffeine)
;;; caffeine.el ends here
