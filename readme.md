# dev-setup

Minimal, reproducible setup for developers on Windows and ALT Linux. Scoop-first on Windows. epm-first on ALT. No PATH hacks, no noise.

## Supported platforms

- Windows 10/11
- ALT Linux (Sisyphus)

## Quick start

Windows

- `git clone https://github.com/e-gleba/dev-setup.git`
- `cd dev-setup/win`
- `.\activate.ps1` (run in a regular PowerShell; elevate only for system-wide components)

ALT Linux

- Ensure sudo is enabled: <https://plafon.gitbook.io/alt-zero/start/sudo>
- Install epm (eepm): `sudo apt-get update && sudo apt-get install -y eepm`
- `git clone https://github.com/e-gleba/dev-setup.git`
- `cd dev-setup/alt`
- `sudo ./alt_dev_setup.sh`

## What gets installed

Windows (via Scoop, fallback only if needed)

- CLI: ripgrep, fzf, hyperfine, bat, fd, eza, jq, zoxide, delta, bottom, duf, dust, procs
- Toolchains: rustup (+rust-analyzer, uutils-coreutils), llvm/clang/lld, mingw, cmake, ninja
- Apps: joplin, mpv, qbittorrent, syncthing
- Debug/net: nmap, wireshark, imhex, ghidra, tracy

ALT Linux (priority: epm play → epmi → apt-get)

- epm play: telegram, steam, yandex-browser, android-studio, gradle, discord, joplin, postman
- Repo: gcc/g++, make, cmake, ninja, pkg-config, clang/llvm/lld/lldb, rustup, rust-analyzer, uutils-coreutils, ripgrep, fzf, hyperfine, bat, fd-find, eza, sd, git-delta, bottom, procs, duf, du-dust, jq, zoxide, mpv, qbittorrent, syncthing, nmap, wireshark, imhex, ghidra, tracy, qtcreator, godot, vcpkg

## Entry points

- Windows: [win/activate.ps1](win/activate.ps1)
- ALT Linux: [alt-linux/setup.sh](alt-linux/alt_dev_setup.sh)

## Notes

- Windows installs prefer user scope (Scoop). Run elevated only for components that require admin.
- ALT Linux installs require root (sudo). For epm docs see: <https://alt-gnome.wiki/epm.html>

## License

See [LICENSE](LICENSE).
