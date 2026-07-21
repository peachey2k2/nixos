;; Music player for Steelix. Uses mpv with a piped command input, so playback
;; controls never need to open a terminal or block the editor.
(require-builtin steel/time)
(require "helix/misc.scm")
(require "cogs/picker.scm")

(provide music-picker
         music-play
         music-pause
         music-resume
         music-toggle
         music-stop
         music-seek-forward
         music-seek-backward
         music-volume-up
         music-volume-down
         music-now-playing)

(define *music-child* (box #f))
(define *music-input* (box #f))
(define *music-file* (box #f))
(define *music-duration* (box 0))
(define *music-position* (box 0))
(define *music-start-second* (box 0))
(define *music-state* (box 'stopped))

(define audio-extensions
  '(".mp3" ".flac" ".ogg" ".oga" ".opus" ".m4a" ".aac" ".wav" ".wave" ".wma" ".ape" ".alac" ".aiff" ".aif" ".mka"))

(define (ignore-errors thunk)
  (with-handler (lambda (_) #f) (thunk)))

(define (music-directory)
  (with-handler
    (lambda (_) (string-append (env-var "HOME") "/Music"))
    (env-var "HELIX_MUSIC_DIR")))

(define (audio-file? path)
  (define lower-path (string-downcase path))
  (let loop ([extensions audio-extensions])
    (and (not (null? extensions))
         (or (ends-with? lower-path (car extensions))
             (loop (cdr extensions))))))

(define (collect-music-files root)
  (define output (capture-output "find" (list root "-type" "f")))
  (if (not (string? output))
      '()
      (let loop ([paths (split-many output "\n")] [files '()])
        (cond
          [(null? paths) (reverse files)]
          [(and (not (equal? (car paths) "")) (audio-file? (car paths)))
           (loop (cdr paths) (cons (car paths) files))]
          [else (loop (cdr paths) files)]))))

(define (music-file-name path)
  (define parts (split-many path "/"))
  (if (null? parts) path (last parts)))

(define (capture-output executable args)
  (ignore-errors
    (lambda ()
      (define child
        (Ok->value
          (spawn-process
            (with-stdout-piped
              (command executable args)))))
      (Ok->value (wait->stdout child)))))

(define (find-prefixed-line prefix lines)
  (cond
    [(null? lines) #f]
    [(starts-with? (car lines) prefix) (car lines)]
    [else (find-prefixed-line prefix (cdr lines))]))

(define (probe-duration path)
  (define output
    (capture-output
      "mpv"
      (list "--no-config"
            "--no-video"
            "--ao=null"
            "--length=0.01"
            "--term-playing-msg=DURATION:${=duration}"
            path)))
  (if (string? output)
      (let ([line (find-prefixed-line "DURATION:" (split-many output "\n"))])
        (if line
            (let ([duration (string->number (trim-start-matches line "DURATION:"))])
              (if duration duration 0))
            0))
      0))

(define (number-argument value fallback)
  (cond
    [(number? value) value]
    [(string? value) (let ([parsed (string->number value)]) (if parsed parsed fallback))]
    [else fallback]))

(define (pad-two value)
  (if (< value 10)
      (string-append "0" (number->string value))
      (number->string value)))

(define (format-time value)
  (define seconds (max 0 (inexact->exact (round value))))
  (define hours (quotient seconds 3600))
  (define minutes (quotient (modulo seconds 3600) 60))
  (define remaining (modulo seconds 60))
  (if (> hours 0)
      (string-append (number->string hours) ":" (pad-two minutes) ":" (pad-two remaining))
      (string-append (pad-two minutes) ":" (pad-two remaining))))

(define (progress-bar position duration)
  (define width 12)
  (define filled
    (if (> duration 0)
        (min width (max 0 (inexact->exact (round (* width (/ position duration))))))
        0))
  (string-append "["
                 (make-string filled #\█)
                 (make-string (- width filled) #\░)
                 "]"))

(define (current-music-position)
  (define position
    (if (equal? (unbox *music-state*) 'playing)
        (+ (unbox *music-position*)
           (- (current-second) (unbox *music-start-second*)))
        (unbox *music-position*)))
  (if (> (unbox *music-duration*) 0)
      (min (unbox *music-duration*) position)
      position))

(define (sync-music-position!)
  (set-box! *music-position* (current-music-position))
  (set-box! *music-start-second* (current-second)))

(define (music-label)
  (if (not (unbox *music-file*))
      ""
      (let ([position (current-music-position)])
        (string-append "♫ "
                       (music-file-name (unbox *music-file*))
                       " "
                       (format-time position)
                       "/"
                       (format-time (unbox *music-duration*))
                       " "
                       (progress-bar position (unbox *music-duration*))
                       (if (equal? (unbox *music-state*) 'paused) " ⏸" " ▶")))))

;; The status is refreshed only by explicit music commands. Delayed Steel
;; callbacks clear Helix's pending key sequence in this revision.
(define (render-music-status!)
  (set-status! (music-label)))

(define (send-mpv-command command)
  (define input (unbox *music-input*))
  (when input
    (ignore-errors
      (lambda ()
        (display (string-append command "\n") input)
        (flush-output-port input)))))

(define (stop-current! announce?)
  (when (unbox *music-child*)
    (send-mpv-command "quit"))
  (set-box! *music-child* #f)
  (set-box! *music-input* #f)
  (set-box! *music-file* #f)
  (set-box! *music-duration* 0)
  (set-box! *music-position* 0)
  (set-box! *music-start-second* 0)
  (set-box! *music-state* 'stopped)
  (when announce? (set-status! "Music stopped")))

;;@doc
;; Play an audio file with mpv. Variadic arguments allow unquoted paths with spaces.
(define (music-play . path-parts)
  (if (null? path-parts)
      (set-warning! "Usage: :music-play <path>")
      (let ([path (string-join path-parts " ")])
        (stop-current! #f)
        (define duration (probe-duration path))
        (define child
          (Ok->value
            (spawn-process
              (with-stdin-piped
                (command
                  "mpv"
                  (list "--no-config"
                        "--no-video"
                        "--input-terminal=yes"
                        "--really-quiet"
                        path))))))
        (set-box! *music-child* child)
        (set-box! *music-input* (child-stdin child))
        (set-box! *music-file* path)
        (set-box! *music-duration* duration)
        (set-box! *music-position* 0)
        (set-box! *music-start-second* (current-second))
        (set-box! *music-state* 'playing)
        (render-music-status!))))

;;@doc
;; Pick and play an audio file. Defaults to $HELIX_MUSIC_DIR or ~/Music.
(define (music-picker [directory #f])
  (define root (if directory directory (music-directory)))
  (define files (collect-music-files root))
  (if (null? files)
      (set-warning! (string-append "No music files found under " root))
      (push-component!
        (picker-selection
          files
          music-play
          #:value-formatter music-file-name
          #:highlight-prefix "▶ "))))

;;@doc
;; Pause music playback.
(define (music-pause)
  (when (equal? (unbox *music-state*) 'playing)
    (sync-music-position!)
    (send-mpv-command "set pause yes")
    (set-box! *music-state* 'paused)
    (render-music-status!)))

;;@doc
;; Resume paused music playback.
(define (music-resume)
  (when (equal? (unbox *music-state*) 'paused)
    (send-mpv-command "set pause no")
    (set-box! *music-start-second* (current-second))
    (set-box! *music-state* 'playing)
    (render-music-status!)))

;;@doc
;; Toggle between paused and playing.
(define (music-toggle)
  (if (equal? (unbox *music-state*) 'paused)
      (music-resume)
      (music-pause)))

;;@doc
;; Stop music playback.
(define (music-stop)
  (stop-current! #t))

(define (seek-by amount)
  (when (not (equal? (unbox *music-state*) 'stopped))
    (sync-music-position!)
    (send-mpv-command (string-append "seek " (number->string amount) " relative"))
    (define position (max 0 (+ (unbox *music-position*) amount)))
    (set-box! *music-position*
              (if (> (unbox *music-duration*) 0)
                  (min (unbox *music-duration*) position)
                  position))
    (set-box! *music-start-second* (current-second))
    (render-music-status!)))

;;@doc
;; Seek forward by N seconds (default: 10).
(define (music-seek-forward [seconds "10"])
  (seek-by (number-argument seconds 10)))

;;@doc
;; Seek backward by N seconds (default: 10).
(define (music-seek-backward [seconds "10"])
  (seek-by (- (number-argument seconds 10))))

;;@doc
;; Increase volume by N percent (default: 5).
(define (music-volume-up [amount "5"])
  (send-mpv-command
    (string-append "add volume " (number->string (number-argument amount 5)))))

;;@doc
;; Decrease volume by N percent (default: 5).
(define (music-volume-down [amount "5"])
  (send-mpv-command
    (string-append "add volume -" (number->string (number-argument amount 5)))))

;;@doc
;; Show the current track and progress in Helix's message row.
(define (music-now-playing)
  (if (unbox *music-file*)
      (set-status! (music-label))
      (set-status! "No music is playing")))
