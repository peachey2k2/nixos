(require "helix/configuration.scm")
(require "helix/misc.scm")
(require "helix/components.scm")
(require "helix/editor.scm")

(provide picker-selection)

(struct MutableTextField (text) #:mutable)
(struct Picker
        (items items-view callback preview-func text-buffer cursor max-length
               window-start value-formatter highlight-prefix default-style
               highlight-style cursor-position))

(define (push-character field char)
  (set-MutableTextField-text! field (cons char (MutableTextField-text field))))

(define (pop-character field)
  (define text (MutableTextField-text field))
  (set-MutableTextField-text! field (if (empty? text) text (cdr text))))

(define (text-field->string field)
  (list->string (reverse (MutableTextField-text field))))

(define (move-cursor-down picker)
  (define count (length (unbox (Picker-items-view picker))))
  (when (> count 0)
    (define current (Picker-cursor picker))
    (define window-start (Picker-window-start picker))
    (set-box! current (modulo (+ 1 (unbox current)) count))
    (when (> (unbox current)
             (+ (unbox window-start) (- (unbox (Picker-max-length picker)) 2)))
      (set-box! window-start (+ (unbox window-start) 1)))
    (when (< (unbox current) (unbox window-start))
      (set-box! window-start (unbox current)))))

(define (move-cursor-up picker)
  (define count (length (unbox (Picker-items-view picker))))
  (when (> count 0)
    (define current (Picker-cursor picker))
    (define window-start (Picker-window-start picker))
    (set-box! current (modulo (- (unbox current) 1) count))
    (when (< (unbox current) (unbox window-start))
      (set-box! window-start (max 0 (- (unbox window-start) 1))))
    (when (> (unbox current)
             (+ (unbox window-start) (- (unbox (Picker-max-length picker)) 2)))
      (set-box! window-start
                (max 0 (- (unbox current) (- (unbox (Picker-max-length picker)) 2)))))))

(define (picker-cursor-handler state _)
  (Picker-cursor-position state))

(define (refilter! state)
  (define matches
    (fuzzy-match (text-field->string (Picker-text-buffer state)) (Picker-items state)))
  (set-box! (Picker-items-view state) matches)
  (set-box! (Picker-cursor state) 0)
  (set-box! (Picker-window-start state) 0))

(define (picker-event-handler state event)
  (define char (key-event-char event))
  (cond
    [(key-event-escape? event) event-result/close]
    [(key-event-down? event) (move-cursor-down state) event-result/consume]
    [(key-event-up? event) (move-cursor-up state) event-result/consume]
    [(key-event-tab? event)
     (if (equal? (key-event-modifier event) key-modifier-shift)
         (move-cursor-up state)
         (move-cursor-down state))
     event-result/consume]
    [(key-event-enter? event)
     (define items (unbox (Picker-items-view state)))
     (when (not (null? items))
       ((Picker-callback state) (list-ref items (unbox (Picker-cursor state)))))
     event-result/close]
    [(key-event-backspace? event)
     (pop-character (Picker-text-buffer state))
     (refilter! state)
     event-result/consume]
    [(char? char)
     (push-character (Picker-text-buffer state) char)
     (refilter! state)
     event-result/consume]
    [(mouse-event? event) event-result/ignore]
    [else event-result/ignore]))

(define (for-each-index func lst index)
  (unless (null? lst)
    (func index (car lst))
    (for-each-index func (cdr lst) (+ index 1))))

(define (picker-render state rect frame)
  (define half-parent-width (round (/ (area-width rect) 2)))
  (define half-parent-height (round (/ (area-height rect) 2)))
  (define starting-x-offset (round (/ (area-width rect) 4)))
  (define starting-y-offset (round (/ (area-height rect) 4)))
  (define block-area
    (area starting-x-offset
          (- starting-y-offset 1)
          half-parent-width
          (min (+ 10 half-parent-height) (- (area-height rect) starting-y-offset))))
  (define x (+ 1 (area-x block-area)))
  (define y (area-y block-area))
  (define start (unbox (Picker-window-start state)))
  (define cursor-position (unbox (Picker-cursor state)))
  (define currently-highlighted (- cursor-position start))
  (define found-style
    (style-fg
      (style-bg (style) (style->bg (theme-scope-ref "ui.background")))
      (style->fg (theme-scope-ref "ui.text"))))
  (set-box! (Picker-max-length state) (area-height block-area))
  (buffer/clear frame block-area)
  (block/render frame
                (area (- (area-x block-area) 1)
                      (- (area-y block-area) 1)
                      (+ 2 (area-width block-area))
                      (+ 2 (area-height block-area)))
                (make-block (theme-scope-ref "ui.background") found-style "all" "plain"))
  (frame-set-string! frame x y (text-field->string (Picker-text-buffer state)) found-style)
  (set-position-row! (Picker-cursor-position state) y)
  (set-position-col! (Picker-cursor-position state)
                     (+ x (length (MutableTextField-text (Picker-text-buffer state)))))
  (define visible
    (slice (unbox (Picker-items-view state)) start (- (unbox (Picker-max-length state)) 1)))
  (for-each-index
    (lambda (index row)
      (define selected? (equal? index currently-highlighted))
      (define text
        (if selected?
            (string-append
              (if (string? (Picker-highlight-prefix state))
                  (Picker-highlight-prefix state)
                  "> ")
              ((Picker-value-formatter state) row))
            (string-append "  " ((Picker-value-formatter state) row))))
      (frame-set-string! frame x (+ index y 1) text found-style))
    visible
    0))

(define (default-formatter value)
  (with-output-to-string (lambda () (display value))))

(define (picker-selection items
                          on-selection
                          #:preview-function [preview-function void]
                          #:value-formatter [formatter default-formatter]
                          #:highlight-prefix [highlight-prefix void]
                          #:default-style [default-style (style)]
                          #:highlight-style [highlight-style (style-bg (style) Color/Gray)])
  (new-component!
    "steel-picker"
    (Picker items (box items) on-selection preview-function
            (MutableTextField '()) (box 0) (box (max 1 (- (length items) 1)))
            (box 0) formatter highlight-prefix default-style highlight-style
            (position 0 0))
    picker-render
    (hash "handle_event" picker-event-handler "cursor" picker-cursor-handler)))
