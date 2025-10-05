# ALT Linux Dev Bootstrap (Sisyphus)

Минимальный bootstrap для ALT Linux: ставит eepm (epm), затем устанавливает пакеты с приоритетом epm play → epmi → apt-get. Ориентирован на C/C++/Rust/Qt и современный CLI-набор. Никаких правок PATH.

## Требования

- ALT Linux (Sisyphus)
- root-доступ (sudo настроен)

Если sudo ещё не настроен — включи его по инструкции:

- <https://plafon.gitbook.io/alt-zero/start/sudo>

## Быстрый старт

- Установи eepm (если не установлен):
  - `sudo apt-get update && sudo apt-get install -y eepm`
- Запусти установщик от root:
  - `sudo ./alt_dev_setup.sh`

Скрипт:

- Проверяет/ставит eepm
- Идёт по спискам пакетов
- Для каждого пакета пробует: epm play → epmi → apt-get
- Не переустанавливает уже установленные пакеты

## Приоритет установки

1. `epm play <имя>` — для приложений из play-реестра
2. `epmi -y <пакет>` — из репозитория ALT
3. `apt-get install -y --no-upgrade <пакет>` — запасной вариант

## Что ставится

- epm play:
  - telegram, steam, yandex-browser, android-studio, gradle, discord, joplin, postman, codium
- Репозитории (epmi/apt-get):
  - Компиляторы/сборка: gcc, gcc-c++, make, cmake, ninja, pkg-config, clang, llvm, lld, lldb, mingw64-gcc
  - Rust: rustup, rust-analyzer, uutils-coreutils
  - CLI: ripgrep, fzf, hyperfine, bat, fd-find, eza, sd, git-delta, bottom, procs, duf, du-dust, jq, zoxide
  - GUI/IDE: qtcreator, godot4, mpv, qbittorrent, syncthing
  - Реверс/сеть: nmap, wireshark, imhex, ghidra, tracy
  - Прочее: p7zip, neovim, vim, nodejs, npm, wget, curl, aria2, kdiff3, vcpkg

## Post-install

- Wireshark без root:
  - `sudo usermod -aG wireshark $USER` и перелогиниться
- Rust:
  - `rustup toolchain install stable`
  - `rustup component add rustfmt clippy`

## Траблшутинг

- epm не найден:
  - `sudo apt-get update && sudo apt-get install -y eepm`
- Пакет не находится:
  - проверь точное имя на packages.altlinux.org (см. ссылки ниже)
- Проприетарные/внешние приложения чаще всего доступны через `epm play`

## Полезные ссылки

- ALT Linux: <https://www.altlinux.org/>
- ALT Linux (EN): <https://en.altlinux.org/Main_Page>
- Поиск пакетов (Sisyphus): <https://packages.altlinux.org/ru/sisyphus/>
- Документация epm/eepm: <https://alt-gnome.wiki/epm.html>
- ALT Zero — sudo: <https://plafon.gitbook.io/alt-zero/start/sudo>
- ALT Zero — epm/eepm: <https://plafon.gitbook.io/alt-zero/start/epm-eepm-help>
- eepm (исходники): <https://github.com/altlinux/eepm>
