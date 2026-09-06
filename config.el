;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

(setq doom-font (font-spec :family "FiraCode Nerd Font" :size 11.0)
      doom-variable-pitch-font (font-spec :family "Noto Sans"))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; PlantUML: use the /usr/bin/plantuml wrapper from the `plantuml' package
;; instead of hunting for a jar; it knows where its own jar lives.
(setq plantuml-default-exec-mode 'executable)
(setq plantuml-jar-path "/usr/share/java/plantuml/plantuml.jar")
(after! org
  (setq org-plantuml-exec-mode 'plantuml))


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;; Claude Code внутри Emacs. Терминальный бэкенд — ghostel (модуль `:term
;; ghostel' уже включён), поэтому vterm/eat не нужны; по умолчанию пакет ждёт
;; vterm, отсюда явный `claude-code-ide-terminal-backend'. Авторизация своя не
;; заводится: пакет запускает CLI `claude' и наследует его логин.
(use-package! claude-code-ide
  :defer t
  :init
  (setq claude-code-ide-terminal-backend 'ghostel
        ;; Дифф забирает фрейм целиком: чат на время сравнения прячется,
        ;; слева оригинал, справа предлагаемый вариант. Прежнюю раскладку
        ;; (код + чат) пакет восстанавливает сам при выходе из ediff.
        claude-code-ide-show-claude-window-in-ediff nil
        ;; Фокус остаётся на диффе, а не прыгает обратно в чат.
        claude-code-ide-focus-claude-after-ediff nil)
  (map! :leader
        (:prefix ("o" . "open")
                 (:prefix ("c" . "claude code")
                  :desc "Toggle window"      "c" #'claude-code-ide-toggle
                  :desc "New session"        "n" #'claude-code-ide
                  :desc "Continue session"   "C" #'claude-code-ide-continue
                  :desc "Resume session"     "r" #'claude-code-ide-resume
                  :desc "Send prompt"        "p" #'claude-code-ide-send-prompt
                  :desc "Insert @mention"    "m" #'claude-code-ide-insert-at-mentioned
                  :desc "List sessions"      "l" #'claude-code-ide-list-sessions
                  :desc "Stop session"       "k" #'claude-code-ide-stop)))
  :config
  ;; Отдаёт мне xref и диагностику проекта через MCP.
  (claude-code-ide-emacs-tools-setup))


;; Завершение ediff-сессии Claude Code одной командой, из любого буфера.
;;
;; Штатный путь — `q' в панели управления — упирается в две вещи сразу: панель
;; надо сперва выбрать окном, а `ediff-mode-map' в ней буфер-локальный, поэтому
;; `evil-make-overriding-map' из evil-collection до него не дотягивается и evil
;; normal state перекрывает `q' своим `evil-record-macro' — вместо выхода
;; начинается запись макроса. Команды ниже находят панель сами и отвечают на
;; оба подтверждения ediff'а, не трогая остальные его вопросы.
(defun +claude/ediff--control-buffer ()
  "Вернуть панель управления активной ediff-сессии (самую свежую)."
  (or (seq-find (lambda (buf)
                  (eq (buffer-local-value 'major-mode buf) 'ediff-mode))
                (buffer-list))
      (user-error "Нет активной сессии ediff")))

(defun +claude/ediff--finish (accept)
  "Закрыть ediff-сессию, приняв правки при ACCEPT и отклонив иначе.
Содержимое правого буфера уходит Claude как есть — вместе с ручными
правками, — а файл на диск пишет он, не Emacs."
  (let ((control (+claude/ediff--control-buffer))
        (answer (symbol-function 'y-or-n-p)))
    (with-current-buffer control
      (cl-letf (((symbol-function 'y-or-n-p)
                 (lambda (prompt)
                   (cond
                    ((string-match-p "Accept the changes" prompt) accept)
                    ((string-match-p "Quit this Ediff session" prompt) t)
                    ;; Прочие вопросы ediff'а оставляем пользователю.
                    (t (funcall answer prompt))))))
        ;; Аргумент обязателен: у `ediff-quit' арность (1 . 1).
        (ediff-quit nil)))))

(defun +claude/ediff-accept ()
  "Принять правки текущего диффа Claude Code и закрыть ediff."
  (interactive)
  (+claude/ediff--finish t))

(defun +claude/ediff-reject ()
  "Отклонить правки текущего диффа Claude Code и закрыть ediff."
  (interactive)
  (+claude/ediff--finish nil))

(defun +claude/ediff-edit ()
  "Перескочить между панелью управления ediff и правым буфером.
В правом буфере лежит предлагаемый вариант — его правят как обычный текст.
`:w' там не нужен и не сработает: буфер не связан с файлом, на диск пишет
Claude после `+claude/ediff-accept'."
  (interactive)
  (let* ((control (+claude/ediff--control-buffer))
         (variant (buffer-local-value 'ediff-buffer-B control))
         (target (if (eq (current-buffer) variant) control variant)))
    (unless (buffer-live-p target)
      (user-error "Буфер ediff-сессии уже закрыт"))
    (if-let* ((window (get-buffer-window target)))
        (select-window window)
      (pop-to-buffer target))))

(map! :leader
      (:prefix ("o" . "open")
               (:prefix ("c" . "claude code")
                :desc "Accept diff" "a" #'+claude/ediff-accept
                :desc "Reject diff" "x" #'+claude/ediff-reject
                :desc "Edit variant" "e" #'+claude/ediff-edit)))

;; Дублируем на аккорд, который проходит в любом evil-стейте: в панели
;; управления leader недоступен, если она окажется в emacs state.
;; Это запасной путь: локальная карта мажорного режима такой бинд перекрывает
;; (например, C-c C-a в go-mode занят go-import-add), поэтому основной — leader.
(map! "C-c C-y" #'+claude/ediff-accept
      "C-c C-n" #'+claude/ediff-reject)

;; И чиним сам `q' в панели: буфер-локальный бинд в normal state бьёт
;; `evil-record-macro' из глобальной карты, при этом j/k/n/p от
;; evil-collection остаются на месте.
(add-hook 'ediff-startup-hook
          (lambda () (evil-local-set-key 'normal "q" #'ediff-quit)))

;; Скриншоты в сессию Claude Code.
;;
;; Пакет изображения не поддерживает вовсе, а вставка картинки из буфера обмена
;; до CLI не доходит: ghostel бинарные данные клипборда не пробрасывает. Зато CLI
;; читает изображение по обычному пути, указанному в промпте, — на этом и строим:
;; grim кладёт снимок в файл, команда впечатывает путь в строку ввода и НЕ
;; отправляет, чтобы можно было дописать вопрос вокруг него.
(defvar +claude/screenshot-directory
  (expand-file-name "claude-shots/" (or (getenv "XDG_CACHE_HOME") "~/.cache/"))
  "Каталог, куда `+claude/send-screenshot' складывает снимки.")

(defun +claude/--wayland-environment ()
  "Вернуть `process-environment' с гарантированным WAYLAND_DISPLAY.
Демон поднимается до сессии Hyprland и своего WAYLAND_DISPLAY не имеет, так
что grim и slurp из него композитор не находят.  Значение берём из окружения
фрейма — его приносит emacsclient, — а если и там пусто, ищем сокет в
XDG_RUNTIME_DIR."
  (if (getenv "WAYLAND_DISPLAY")
      process-environment
    (let* ((frame-env (frame-parameter (selected-frame) 'environment))
           (inherited (seq-find (lambda (var) (string-prefix-p "WAYLAND_DISPLAY=" var))
                                frame-env))
           (runtime (getenv "XDG_RUNTIME_DIR"))
           (socket (car (and runtime
                             (directory-files runtime nil "\\`wayland-[0-9]+\\'")))))
      (cond
       (inherited (cons inherited process-environment))
       (socket (cons (concat "WAYLAND_DISPLAY=" socket) process-environment))
       (t (user-error "Не найден WAYLAND_DISPLAY — grim и slurp не увидят композитор"))))))

(defun +claude/--screenshot-region ()
  "Спросить область через slurp и вернуть её геометрию для `grim -g'."
  (with-temp-buffer
    (unless (zerop (call-process "slurp" nil t nil))
      (user-error "Выделение области отменено"))
    (string-trim (buffer-string))))

(defun +claude/send-screenshot (&optional whole-screen)
  "Снять скриншот и впечатать путь к нему в строку ввода сессии Claude Code.
Без префикса просит выделить область через slurp; с префиксом (`C-u')
снимает вывод целиком.  Промпт не отправляется — допиши вопрос и жми RET."
  (interactive "P")
  (dolist (tool (if whole-screen '("grim") '("grim" "slurp")))
    (unless (executable-find tool)
      (user-error "Не найден %s" tool)))
  ;; `claude-code-ide--resolve-session' трактует любой префикс как «спроси,
  ;; в какую сессию», а здесь префикс занят под полный экран — развязываем.
  (let* ((session (let ((current-prefix-arg nil))
                    (claude-code-ide--resolve-session 'auto "Скриншот в сессию: ")))
         (buffer (and session (claude-code-ide-mcp-session-buffer session))))
    (unless (buffer-live-p buffer)
      (user-error "Нет активной сессии Claude Code"))
    (make-directory +claude/screenshot-directory t)
    ;; Динамическая привязка накрывает и slurp, и grim ниже.
    (let* ((process-environment (+claude/--wayland-environment))
           (file (expand-file-name (format-time-string "shot-%Y%m%d-%H%M%S.png")
                                   +claude/screenshot-directory))
           ;; Область спрашиваем до запуска grim, иначе снимок застанет slurp.
           (geometry (unless whole-screen (+claude/--screenshot-region)))
           (args (if geometry (list "-g" geometry file) (list file))))
      (unless (zerop (apply #'call-process "grim" nil nil nil args))
        (user-error "grim не смог снять скриншот"))
      (with-current-buffer buffer
        (claude-code-ide--terminal-send-string (concat file " ")))
      (when-let* ((window (get-buffer-window buffer)))
        (select-window window)
        (evil-insert-state))
      (message "Скриншот: %s" file))))

(map! :leader
      (:prefix ("o" . "open")
               (:prefix ("c" . "claude code")
                :desc "Screenshot to session" "s" #'+claude/send-screenshot)))

;; Буфер сессии — emacs state, там `SPC' уходит в CLI как обычный пробел, а
;; leader переезжает на `M-SPC'. Чтобы не помнить об этом, дублируем на аккорд:
;; в ghostel-буфере `C-c C-s' свободен и до Emacs доходит.
(map! "C-c C-s" #'+claude/send-screenshot)

;; Запуск программы — через `compile', а не quickrun: модуль `:tools (eval
;; +overlay)' переопределяет `quickrun--pop-to-buffer' и рисует результат
;; оверлеем в буфере с кодом (или попапом *doom eval* снизу), так что до
;; собственного окна quickrun дело не доходит. К тому же шаблон quickrun для Go
;; — `go run <файл>', и на втором файле в пакете сборка отваливается.
;;
;; Full-frame даёт `display-buffer-overriding-action': он приоритетнее
;; `display-buffer-alist', где живут popup-правила Doom, а `compilation-start'
;; показывает буфер синхронно, так что `let' успевает сработать.

(defun +go/run ()
  "Запустить текущий пакет Go, вывод — на весь фрейм.
`q' в буфере вывода вернёт прежнюю раскладку окон."
  (interactive)
  (window-configuration-to-register :compile-fullscreen)
  (let ((default-directory (or (locate-dominating-file default-directory "go.mod")
                               default-directory))
        (display-buffer-overriding-action '((display-buffer-full-frame))))
    (compile "go run .")))

(defun +compile/restore-wconf ()
  "Вернуть раскладку окон, сохранённую перед запуском `+go/run'.
Если её нет (буфер сборки открыт чем-то другим) — обычный `quit-window'."
  (interactive)
  (if (get-register :compile-fullscreen)
      (progn (jump-to-register :compile-fullscreen)
             (set-register :compile-fullscreen nil))
    (quit-window)))

;; Биндинг ставится буфер-локально, а не в `compilation-mode-map': evil-collection
;; вешает на `q' `quit-window' в том же мапе, и кто из нас окажется последним —
;; зависит от порядка загрузки. Буфер-локальный evil-мап перекрывает оба.
(add-hook! 'compilation-mode-hook
  (defun +compile-rebind-quit-h ()
    (evil-local-set-key 'normal "q" #'+compile/restore-wconf)))

(defun +run/dwim ()
  "Запустить текущий буфер: в Go — `+go/run', иначе — штатный `+eval/buffer'."
  (interactive)
  (if (derived-mode-p 'go-mode 'go-ts-mode)
      (+go/run)
    (+eval/buffer)))

(map! :n "<f5>" #'+run/dwim)

;; Долгоживущие процессы (API-сервер) — не через `compile', а в терминале.
;; `go run' — обёртка: она собирает бинарь и запускает его отдельным процессом,
;; сигналы ему не пробрасывая. `compile' общается с процессом через пайп и шлёт
;; SIGINT только обёртке, так что сервер осиротеет и продолжит держать порт.
;; В настоящем PTY Ctrl-C идёт всей передней группе процессов — умирают оба.
(defun +go/serve ()
  "Запустить текущий пакет Go в терминале — для долгоживущих процессов (API).
Остановить — `i', затем `C-c' (evil-ghostel пробрасывает Ctrl-клавиши в
приложение только из insert-состояния). `g' в остановленном буфере — заново."
  (interactive)
  (let* ((root (or (locate-dominating-file default-directory "go.mod")
                   default-directory))
         (default-directory root)
         (display-buffer-overriding-action '((display-buffer-full-frame))))
    (window-configuration-to-register :compile-fullscreen)
    ;; `dlet', а не `let': ghostel-compile.el грузится по автозагрузке, и в
    ;; lexical-binding обычный `let' на ещё не объявленную переменную создал бы
    ;; лексическую привязку, которой команда не увидит.
    (dlet ((ghostel-compile-buffer-name
            (format "*go serve:%s*"
                    (file-name-nondirectory (directory-file-name root)))))
      (ghostel-compile "go run ." t))))

(map! :n "<f6>" #'+go/serve)

;; TAB при открытом попапе corfu достаётся corfu-map (он перекрывает глобальный
;; «умный TAB» evil'а), поэтому сниппеты не разворачивались: попап всплывает уже
;; после двух символов, а выхода из него, оставляющего в insert-состоянии, нет —
;; C-g перехватывает `evil-escape'. С этой опцией TAB сначала проверяет, не
;; является ли слово перед курсором триггером сниппета. Листать кандидатов —
;; C-j / C-k (или C-n / C-p).
(setq +corfu-want-tab-prefer-expand-snippets t)


;;
;;; SQL: клиент Clutch
;;
;; `clutch-mode' — наследник `sql-mode', поэтому в нём работают и сниппеты из
;; snippets/sql-mode (yasnippet ходит по цепочке наследования), и apheleia
;; (она выбирает форматтер через `provided-mode-derived-p'). `C-c C-c'
;; выполняет выделенный регион, а без выделения — statement под курсором;
;; результат открывается окном снизу и переиспользуется следующими запросами.

;; Запрос пароля от gpg-ключа — минибуфером Emacs, а не через pinentry.
;; `auth-source-pass' не зовёт CLI `pass': он читает ~/.password-store/*.gpg
;; через `epa-file-handler', то есть расшифровывает сам Emacs. Дальше gpg идёт
;; в `gpg-agent', тот запускает /usr/bin/pinentry — а это на Arch bash-обёртка,
;; выбирающая бэкенд по $DISPLAY/$XDG_SESSION_TYPE *своего* окружения. Агент
;; этих переменных не видит, откатывается на curses/tty, а у процесса из
;; emacs-демона терминала нет → «Inappropriate ioctl for device».
;; Loopback убирает pinentry из цепочки целиком: Emacs спрашивает пароль сам и
;; отдаёт его gpg напрямую. Действует на любые .gpg внутри Emacs, не только на
;; pass. Цена — кэш gpg-agent в этом режиме не используется, спрашивать будет
;; чаще. (`epa-pinentry-mode' — устаревший с 27.1 алиас, нужен именно epg-.)
(setq epg-pinentry-mode 'loopback)

;; `pass' как источник паролей. Clutch читает запись напрямую через
;; `auth-source-pass-parse-entry', минуя `auth-sources', но функции этой
;; библиотеки должны быть загружены — отсюда `require'. Именно `require', а не
;; `auth-source-pass-enable': глобальный список `auth-sources' не трогаем,
;; чтобы не менять поведение magit/forge.
(require 'auth-source-pass)

;; Пароли в конфиге не держим. Для сохранённого подключения clutch НЕ спросит
;; пароль в минибуфере (`read-passwd' есть только в ручном ad-hoc-потоке) —
;; если ничего не нашлось, он молча уйдёт с пустым паролем и словит
;; «password authentication failed». Порядок поиска:
;;   1. `:password' прямо в записи ниже — так не делаем;
;;   2. `:pass-entry' — подставляется автоматически из имени подключения и
;;      ищется в ~/.password-store по суффиксу пути, то есть «local-pg»
;;      находит «clutch/local-pg»: `pass insert clutch/local-pg';
;;   3. `auth-source-search' по :host/:user/:port — строка в ~/.authinfo.gpg
;;      вида `machine 127.0.0.1 login enot port 5432 password …'.
(setq clutch-connection-alist
      '(("local-pg" . (:backend pg
                       :host "127.0.0.1" :port 5432
                       :user "enot" :database "server-db"))
        ("supabase-weightapp" . (:backend pg
                                 :host "127.0.0.1" :port 54322
                                 :user "supabase_admin" :database "postgres"))
        ("local-redis" . (:backend redis
                          :host "127.0.0.1" :port 6379
                          :database 0))))

;; Буферы результата, записи и describe наследуются от `special-mode', а
;; evil-collection про clutch ещё не знает. В normal-состоянии его однобуквенные
;; команды (`s' — сортировка колонки, `i'/`d' — правки строк, `C' — прыжок по
;; колонкам, `{'/`}' — к краям таблицы) перекрывались бы операторами evil, так
;; что отдаём эти буферы пакету целиком. Вернуться в evil — `C-z'.
(set-evil-initial-state! '(clutch-result-mode
                           clutch-record-mode
                           clutch-describe-mode)
  'emacs)

;; `.sql' намеренно не перехватываем: миграции удобнее открывать в обычном
;; `sql-mode'. Включить clutch в открытом файле — `M-x clutch-mode', дальше
;; `C-c C-e' для подключения.

(defun +sql/console ()
  "Открыть консоль запросов clutch в отдельном workspace «sql»."
  (interactive)
  (let ((fresh (not (+workspace-exists-p "sql"))))
    (+workspace-switch "sql" t)
    (when fresh (delete-other-windows)))
  (call-interactively #'clutch-query-console))

(map! :leader :desc "SQL console" "o s" #'+sql/console)

(map! :after clutch
      :map clutch-mode-map
      :localleader
      :desc "Выполнить регион/statement" "e" #'clutch-execute-dwim
      :desc "Выполнить буфер"            "E" #'clutch-execute-buffer
      :desc "Подключиться / сменить БД"  "c" #'clutch-connect
      :desc "Сменить схему"              "s" #'clutch-switch-schema
      :desc "Объекты БД"                 "j" #'clutch-jump
      :desc "Описание объекта"           "d" #'clutch-describe-dwim
      :desc "Меню clutch"                "?" #'clutch-dispatch)
