# 2. GitHub: доступ, скачивание проекта, вход в `gh`

Репозиторий приватный — доступ есть только у приглашённых участников.

## Шаг 1. Аккаунт и приглашение
1. Если аккаунта на GitHub нет — зарегистрируйся на https://github.com/signup.
2. Напиши владельцу репозитория свой логин GitHub — он отправит приглашение.
3. Приглашение придёт на почту. Нажми в письме **View invitation**, затем **Accept invitation**.
   Письма нет — открой https://github.com/snorexia/the-menders-tale/invitations.

**Должно получиться:** страница https://github.com/snorexia/the-menders-tale открывается, а не показывает «404».

## Шаг 2. Вход в GitHub Desktop
1. Открой **GitHub Desktop**.
2. Нажми **File → Options → Accounts → Sign in** (у GitHub.com).
3. Откроется браузер — войди и нажми **Authorize desktop**. Браузер может спросить, открыть ли GitHub Desktop — разреши.

**Должно получиться:** в **File → Options → Accounts** виден твой аккаунт.

## Шаг 3. Включить Git LFS (один раз на ПК)
1. Нажми **Пуск**, введи `PowerShell`, открой **Windows PowerShell**.
2. Введи:
   ```
   git lfs install
   ```

**Должно получиться:** `Git LFS initialized.`

## Шаг 4. Скачать проект
1. В GitHub Desktop: **File → Clone repository**.
2. Вкладка **GitHub.com** → выбери `snorexia/the-menders-tale`.
3. В поле **Local path** выбери папку, куда положить проект (любая, лучше без кириллицы в пути). Запомни её.
4. Нажми **Clone**. Картинки скачиваются через LFS — это может занять пару минут.

**Должно получиться:** вверху **Current repository: the-menders-tale**, **Current branch: dev**.

## Шаг 5. Проверить ветку `dev`
Вся работа идёт в ветке `dev` (`main` — только для готового продукта).
1. Вверху нажми **Current branch**.
2. Выбери **dev**.
3. Нажми **Fetch origin**, а если появится кнопка **Pull origin** — нажми её.

## Шаг 6. Вход в GitHub CLI (`gh`)
Нужен, чтобы Claude создавал задачи, PR и работал с доской.
1. Открой **Windows PowerShell** и введи:
   ```
   gh auth login
   ```
2. Отвечай стрелками и Enter:
   - `Where do you use GitHub?` → **GitHub.com**
   - `What is your preferred protocol?` → **HTTPS**
   - `Authenticate Git with your GitHub credentials?` → **Yes**
   - `How would you like to authenticate?` → **Login with a web browser**
3. Появится строка `First copy your one-time code: XXXX-XXXX`. Это код из 8 символов.
4. Нажми Enter — откроется браузер. Введи код в клетки (дефис не нужен), нажми **Continue**, затем **Authorize github**.
5. Дай доступ к доске задач — введи:
   ```
   gh auth refresh -h github.com -s project
   ```
   и пройди те же шаги с новым кодом.

**Должно получиться:** команда `gh auth status` показывает `✓ Logged in to github.com account <твой логин>`, а в строке `Token scopes` есть `project`.

Код никому не пересылай и в чат не вставляй — он нужен только в браузере.

## Частые проблемы
- **Страница репозитория — 404** → приглашение не принято или отправлено не на тот логин. Шаг 1.
- **Не вижу `snorexia/the-menders-tale` при клонировании** → в GitHub Desktop вошёл не тот аккаунт (шаг 2) или приглашение не принято.
- **Картинки в проекте открываются как текст «version https://git-lfs…»** → не выполнен шаг 3. Выполни `git lfs install`, затем в папке проекта: `git lfs pull`.
- **Не вижу, где взять код для `gh`** → он печатается в окне PowerShell, где запущена команда, над строкой `Press Enter to open…`. Код живёт около 15 минут — истёк, запусти команду заново.
- **`gh` говорит `missing required scopes [read:project]`** → не выполнен пункт 5 шага 6.

Дальше: [03-claude-code.md](03-claude-code.md).
