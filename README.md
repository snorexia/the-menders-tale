# The Mender's Tale

Сюжетная игра про средневековую ремонтную мастерскую для ПК (Steam). Рабочее название.

> Этап 2: сценарий и вектор игры. Механики и архитектура ещё не определены — в репозитории правила работы, процесс и исходная идея.

**Новичкам — сюда:** [docs/onboarding/README.md](docs/onboarding/README.md) — пошаговая настройка ПК и как работать с Claude.

![Референс — прилавок](docs/reference/mockups/01-counter-customer.png)

## С чего начать

| Что | Где |
|---|---|
| Исходная идея игры | [docs/game/original-brief.md](docs/game/original-brief.md) |
| Где остановились | [docs/process/status.md](docs/process/status.md) |
| Как мы работаем: роли, задачи, ветки, этапы | [docs/process/workflow.md](docs/process/workflow.md) |
| Настройка ПК и ежедневная работа | [docs/onboarding/](docs/onboarding/README.md) |
| Инструменты | [docs/process/tools.md](docs/process/tools.md) |
| Визуальные референсы | [docs/reference/](docs/reference/README.md) |
| Правила для ИИ-агентов | [CLAUDE.md](CLAUDE.md) — агенты читают первым; Codex — [AGENTS.md](AGENTS.md) |

## Структура

```
docs/
  game/        Идея игры (дальше — сценарий и решения по механикам)
  process/     Как мы работаем, инструменты, статус
  onboarding/  Пошаговые инструкции для участников + словарик
  art/         Журнал ассетов
  reference/   Мокапы-референсы
tools/         Сохранённые скрипты для инструментов
_archive/      Устаревшее и ранние черновики — не решения
.github/       Шаблоны задач (основная, ИИ-подзадача, баг) и pull request
.claude/
  rules/       Правила для ИИ по темам (индекс — в CLAUDE.md)
    lessons/   Набитые шишки по ролям
  skills/      Скиллы агента (grill-me — планирование)
CLAUDE.md      Главные правила для ИИ
AGENTS.md      Вход для Codex и других агентов
CLAUDE.local.md  Личные заметки о своём ПК (у каждого свой, в git не попадает)
```

Ветки: `dev` — разработка и тесты (сюда все PR), `main` — готовый продукт.

Структура будет расширяться по мере принятия решений — отдельными задачами.
