# Порт Pomodoro на macOS — с чего начать

Папка `docs/macos/` — всё, что нужно, чтобы написать нативную версию таймера для Mac с помощью
Claude Code, не глядя в Windows-код руками. Windows-приложение (C# / WPF в корне репозитория)
остаётся эталоном поведения.

| Файл | Что это |
|---|---|
| [SPEC.md](SPEC.md) | Спецификация поведения: настройки, движок таймера, оба окна, иконка в строке меню, уведомления, звуки, цвета, локализация, что на Mac сознательно сделано иначе |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Как устроен порт: Swift-пакет в `macos/`, разделение AppKit / SwiftUI, скрипт сборки `.app`, тесты, проверенные факты о macOS API, релиз |
| [KICKOFF.md](KICKOFF.md) | Готовый промпт для Claude Code на Mac и порядок фаз |

Скриншоты текущей сборки: [фокус](screenshots/main-light-focus.png), [вкладка Break во время фокуса](screenshots/main-light-break-view.png), [компакт](screenshots/compact-light.png), [редактор длительности](screenshots/main-light-edit.png), настройки: [Таймер](screenshots/settings-timer.png), [Звук](screenshots/settings-sound.png), [Внешний вид, тёмная](screenshots/settings-appearance-dark.png), [Система по-русски](screenshots/settings-system-ru.png).

## Что нужно на MacBook

1. macOS 13 Ventura или новее.
2. Xcode 15+ **или** только Command Line Tools (`xcode-select --install`). Проверено: Command Line
   Tools достаточно для сборки, тестов и `.app`; Xcode ставить не обязательно.
3. Git и SSH-ключ, добавленный в GitHub (репозиторий клонируется по `git@github.com:Shimodos/PomodoroTimer.git`).
4. Claude Code, установленный по официальной инструкции с claude.com/claude-code.

## Порядок действий

```bash
git clone git@github.com:Shimodos/PomodoroTimer.git
```

```bash
cd PomodoroTimer
```

```bash
claude
```

Дальше вставить промпт из [KICKOFF.md](KICKOFF.md). Claude Code прочитает спецификацию и
архитектуру, создаст `macos/` и пойдёт по фазам, останавливаясь после каждой. Запускать Claude Code
нужно из корня репозитория, а не из `macos/`, чтобы Windows-исходники были доступны как справка.

## Как проверять

Из папки `macos/`:

```bash
make test
```

```bash
POMODORO_DATA_DIR=/tmp/pomo make run
```

`make test` гоняет юнит-тесты логики на Swift Testing (движок, расписание, настройки, локализация,
цвета, тексты сессий, логи).
`make run` собирает `macos/build/Pomodoro.app` и открывает его. Переменная `POMODORO_DATA_DIR`
уводит настройки и логи в отдельную папку, чтобы не трогать настоящие
(`~/Library/Application Support/PomodoroTimer/`). Ручной чек-лист из десяти пунктов — в
[ARCHITECTURE.md, §6](ARCHITECTURE.md#6-tests).

Запускать приложение надо именно через `make run` (как `.app`), а не `swift run`: без бандла
не работают уведомления, иконка и автозапуск.

## Что заведомо не совпадает с Windows

Нативная рамка окна со «светофором» вместо своих кнопок свернуть/закрыть, иконка в строке меню
вместо трея (клик открывает меню, первый пункт «Показать»), системные уведомления macOS, «Открывать
при входе» вместо автозапуска через реестр, SF Symbols вместо Fluent-иконок, системный шрифт SF Pro.
Полный список — в [SPEC.md, §16](SPEC.md#16-accepted-differences). Файл `settings.json` общий: его
можно скопировать с Windows и получить те же настройки.
