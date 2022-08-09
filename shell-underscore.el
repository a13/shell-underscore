;;; shell-underscore.el --- Add _ as a shorthand in shell mode for the last shell output

;; Copyright (C) 2022-2022  Mathias Dahl

;; Author: Mathias Dahl <mathias.dahl@gmail.com>
;; Maintainer: Mathias Dahl <mathias.dahl@gmail.com>
;; Version: 1.0.0
;; Keywords: convenience
;; URL: http://www.emacswiki.org/cgi-bin/wiki.pl?ShellUnderscore

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This package enables the use of an underscore (`_') character as a
;; shorthand for a temporary file containing the last shell output.

;; Please see README.md from the same repository for documentation.

;;; Code:

(defvar shell-underscore-last-output-file nil)

(defun shell-underscore-temp-file-name (name)
  "Generate the temporary file name for NAME."
  (concat temporary-file-directory "shell-output-" name))

(defun shell-underscore-write-last-output (&optional name force)
  "Write the last shell output to a file and return the file name.
NAME is either a letter or a number used to construct a fixed
file name.  A non nil value for FORCE forces any named file to
be overwritten with the last result."
  (let (file)
    (if name
        (progn (setq file (shell-underscore-temp-file-name name))
               (if (or (not (file-exists-p file))
                       force)
                   (comint-write-output file)))
      (setq file (make-temp-file "shell-output-"))
      (comint-write-output file))
    file))

(defun shell-underscore-save-output (text)
  "If command ends in _, save last output TEXT to file."
  (when (string-match "\\(.*\\) _\\($\\| \\)" text)
    (setq shell-underscore-last-output-file (shell-underscore-write-last-output)))

  (when (string-match "\\(.*\\) _\\([a-z0-9]\\)\\($\\| \\)" text)
    (setq shell-underscore-last-output-file (shell-underscore-write-last-output (match-string 2 text))))

  (when (string-match "\\(.*\\) _\\([a-z0-9]\\)!\\($\\| \\)" text)
    (setq shell-underscore-last-output-file (shell-underscore-write-last-output (match-string 2 text) t))))

(defun shell-underscore-send-command (proc command)
  "If command ends in _, replace with file containing last output.
PROC is the process to send COMMAND to."
  (let ((command (shell-underscore-transform-command command shell-underscore-last-output-file)))
    (comint-simple-send proc command)))

(defun shell-underscore-transform-command (command temp-file)
  "Transform COMMAND, replace _ with the TEMP-FILE."
  (let ((transformed-command command) file)
    (when (string-match ".* \\(_[a-z0-9]?\\)!?\\($\\| \\)" transformed-command)
      (setq file (format "/tmp/%s" (file-name-nondirectory temp-file)))
      (setq transformed-command
            (replace-regexp-in-string ".* \\(_[a-z0-9]?!?\\)" file command nil nil 1))
      (message "Transformed command to: %s" transformed-command))
    transformed-command))

(define-minor-mode shell-underscore-mode
  "Toggle shell hacks underscore mode.
Shell hacks underscore mode let you access the last shell output
saved in a file with the shorthand `_'.

Examples:

 $ echo hello
 hello
 $ tr 'h' 'H' < _
 Hello
 $

 $ some complex shell command
 bar
 baz
 foo
 $ grep b _
 bar
 baz
 $

It's also possible to have the underscore in the middle of a command:

 $ cat test
 bar
 baz
 foo
 $ grep b _ | grep z
 baz
 $

In order to work correctly, your prompt can only consist of one
line.

This saves saves you from using pipes, which can be handy if a
command that produce the initial input takes a long time to
execute or you cannot run it again because of its side effects.
It also saves you from redirecting the output on beforehand.

If you want to access a certain output file later by its real
name, you can simply find the name in the following way:

 $ ls _
 /tmp/shell-output-NHuKHW
 $

Each time you use `_' it will be a different file that is
used (because at each command invocation that uses the
underscore, new output is generated and saved).  If you want to
persist a certain output, suffix the `_' with a letter (a-z) or a
number.  When you do that, the content in the file will not
change if you refer to it with an underscore and that letter or
number again and you can refer to the same file and therefore
file content over and over again.  If you want to overwrite one
of the named output files, add a `!' after the letter.

Example:

 $ cat foo
 hello
 hi
 hey

 $ grep e _a
 hello
 hey

 $ grep i _a
 hi

 $ cat bar
 bye
 good bye

 $ grep g _a!
 good bye

 $ grep b _a
 bye
 good bye"
  :lighter nil
  (if shell-underscore-mode
      (progn
        (add-hook 'comint-input-filter-functions #'shell-underscore-save-output nil t)
        (setq comint-input-sender 'shell-underscore-send-command))
    (remove-hook 'comint-input-filter-functions #'shell-underscore-save-output t)
    (setq comint-input-sender #'comint-simple-send)))

(provide 'shell-underscore)

;;; shell-underscore.el ends here