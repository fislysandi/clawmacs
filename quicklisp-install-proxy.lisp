(defparameter *quicklisp-url* "https://beta.quicklisp.org/quicklisp.lisp")

(defun getenv* (name)
  (let ((pkg (find-package :SB-EXT)))
    (when pkg
      (let ((sym (find-symbol "POSIX-GETENV" pkg)))
        (when (and sym (fboundp sym))
          (funcall sym name))))))

(defun command-line-args* ()
  (let ((pkg (find-package :SB-EXT)))
    (if pkg
        (let ((sym (find-symbol "*POSIX-ARGV*" pkg)))
          (if (and sym (boundp sym))
              (cdr (symbol-value sym))
              '()))
        '())))

(defun first-non-empty (&rest values)
  (find-if (lambda (v) (and (stringp v) (> (length v) 0))) values))

(defun detect-proxy-url ()
  (first-non-empty
   (getenv* "HTTPS_PROXY")
   (getenv* "https_proxy")
   (getenv* "HTTP_PROXY")
   (getenv* "http_proxy")
   (getenv* "ALL_PROXY")
   (getenv* "all_proxy")))

(defun file-exists-p (path)
  (not (null (probe-file path))))

(defun run-command (program args)
  (let ((proc (sb-ext:run-program program args :search t :input nil :output *standard-output* :error *error-output*)))
    (sb-ext:process-exit-code proc)))

(defun command-success-p (program args)
  (handler-case
      (eql 0 (run-command program args))
    (error () nil)))

(defun ensure-quicklisp-loader (loader-path)
  (unless (file-exists-p loader-path)
    (format t "[quicklisp] '~A' not found. Downloading from ~A ...~%" loader-path *quicklisp-url*)
    (unless (or (command-success-p "curl" (list "-fL" "--retry" "3" "--connect-timeout" "20" "-o" loader-path *quicklisp-url*))
                (command-success-p "wget" (list "-O" loader-path *quicklisp-url*)))
      (error "Failed downloading quicklisp.lisp. curl/wget unavailable or download failed.")))
  (format t "[quicklisp] Loader ready: ~A~%" loader-path))

(defun ensure-sbcl-init-loads-quicklisp ()
  (let* ((init-path (merge-pathnames ".sbclrc" (user-homedir-pathname)))
         (snippet
          (format nil
                  "~%;; Added by quicklisp-install-proxy.lisp~%#-quicklisp~%(let ((quicklisp-init (merge-pathnames \"quicklisp/setup.lisp\" (user-homedir-pathname))))~%  (when (probe-file quicklisp-init)~%    (load quicklisp-init)))~%"))
         (existing (if (probe-file init-path)
                       (with-open-file (in init-path :direction :input)
                         (let ((content (make-string (file-length in))))
                           (read-sequence content in)
                           content))
                       "")))
    (unless (search "quicklisp/setup.lisp" existing)
      (with-open-file (out init-path :direction :output :if-exists :append :if-does-not-exist :create)
        (write-string snippet out)))
    (format t "[quicklisp] Ensured ~~/.sbclrc loads quicklisp/setup.lisp.~%")))

(defun set-quicklisp-proxy (proxy-url)
  (when proxy-url
    (let ((pkg (find-package :QL-HTTP)))
      (when pkg
        (let ((sym (find-symbol "*PROXY-URL*" pkg)))
          (when (and sym (boundp sym))
            (setf (symbol-value sym) proxy-url)
            (format t "[quicklisp] ql-http:*proxy-url* set.~%")))))))

(defun run-quicklisp-install (proxy-url)
  (let ((pkg (find-package :QUICKLISP-QUICKSTART)))
    (unless pkg
      (error "QUICKLISP-QUICKSTART package not found after loading quicklisp.lisp"))
    (let ((sym (find-symbol "INSTALL" pkg)))
      (unless (and sym (fboundp sym))
        (error "QUICKLISP-QUICKSTART:INSTALL function not found"))
      (if proxy-url
          (progn
            (format t "[quicklisp] Installing with proxy argument...~%")
            (funcall sym :proxy proxy-url))
          (funcall sym)))))

(defun main ()
  (handler-case
      (let* ((proxy-url (detect-proxy-url))
             (loader-path (or (first (command-line-args*)) "quicklisp.lisp")))
        (if proxy-url
            (format t "[quicklisp] Proxy detected: ~A~%" proxy-url)
            (format t "[quicklisp] No proxy detected. Proceeding without proxy override.~%"))

        (ensure-quicklisp-loader loader-path)
        (load loader-path)
        (set-quicklisp-proxy proxy-url)

        (run-quicklisp-install proxy-url)
        (ensure-sbcl-init-loads-quicklisp)

        (format t "[quicklisp] Done.~%"))
    (error (e)
      (format *error-output* "[quicklisp] ERROR: ~A~%" e)
      (sb-ext:exit :code 1))))

(main)
