#!/usr/bin/env bash
# alt_dev_setup.sh
# ALT Linux (Sisyphus): install eepm first, then install packages with priority:
# epm play -> epmi -> apt-get, without overriding installed packages.
# Style: minimal, strict, snake_case.

set -Eeuo pipefail
trap 'echo "error: failed at line $LINENO" >&2' ERR

usage() {
  cat <<'EOF'
usage: sudo ./alt_dev_setup.sh

- Run as root. If you are not root, enable sudo: https://plafon.gitbook.io/alt-zero/start/sudo
- Priority: epm play -> epmi -> apt-get (no overrides if already installed)
tldr:
su -
control sudowheel enabled
exit
EOF
}

is_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

apt_update_once() {
  if [[ "${_APT_UPDATED:-0}" -eq 0 ]]; then
    echo ":: apt-get update"
    apt-get update -y
    _APT_UPDATED=1
  fi
}

ensure_eepm() {
  if ! need_cmd epm; then
    echo ":: installing eepm (epm)"
    apt_update_once
    # install if missing; do not upgrade if present
    apt-get install -y --no-upgrade eepm
  fi
}

# --------------------------
# install helpers
# --------------------------
install_play() {
  echo ":: epm play -y $name"
  if epm play -y "$name"; then
    echo "==> ok: $name via epm play"
    return 0
  fi
  return 1
}

install_epmi() {
  local name="$1"
  # for repo packages, check rpm db first to avoid reinstall/upgrade
  if rpm -q "$name" >/dev/null 2>&1; then
    echo "==> skip (rpm installed): $name"
    return 0
  fi
  echo ":: epmi -y $name"
  if epmi -y "$name"; then
    echo "==> ok: $name via epmi"
    return 0
  fi
  return 1
}

install_apt() {
  local name="$1"
  if rpm -q "$name" >/dev/null 2>&1; then
    echo "==> skip (rpm installed): $name"
    return 0
  fi
  echo ":: apt-get install -y --no-upgrade $name"
  if apt-get install -y --no-upgrade "$name"; then
    echo "==> ok: $name via apt-get (no-upgrade)"
    return 0
  fi
  return 1
}

install_with_priority() {
  local name="$1"
  # 1) play for known play-entries
  if [[ " ${EPM_PLAY_LIST[*]} " == *" $name "* ]]; then
    install_play "$name" && return 0
  fi
  # 2) repo via epmi
  install_epmi "$name" && return 0
  # 3) fallback apt-get (no-upgrade)
  install_apt "$name" && return 0

  echo "!! fail: $name (all methods failed)" >&2
  return 1
}

# --------------------------
# package lists
# --------------------------
# epm play candidates
EPM_PLAY_LIST=(
  telegram
  steam
  yandex-browser
  android-studio
  gradle
  discord
  joplin
  postman
)

# repo packages
REPO_LIST=(
  # core platform
  git
  p7zip
  neovim
  vim
  cmake
  ninja-build
  python3
  pip
  nodejs
  npm
  wget
  curl
  aria2

  # CLI productivity
  ripgrep
  fzf
  hyperfine
  bat
  fd
  eza
  sd
  git-delta
  bottom
  procs
  duf
  du-dust
  jq
  zoxide

  # Rust + analyzers
  rust-analyzer
  uutils-coreutils

  # Compilers / toolchains
  gcc
  gcc-c++
  make
  pkg-config
  clang-tools
  llvm
  mingw64-gcc

  # Desktop apps
  kdiff3
  mpv
  qbittorrent
  syncthing

  # Security / network / debug
  nmap
  wireshark
  imhex
  qtcreator
  godot4
  vcpkg
)

main() {
  if ! is_root; then
    echo "error: run as root. If you don't have sudo, enable it first: https://plafon.gitbook.io/alt-zero/start/sudo" >&2
    usage
    exit 1
  fi

  apt_update_once
  ensure_eepm

  echo "==> epm play list:"
  printf '  - %s\n' "${EPM_PLAY_LIST[@]}"

  echo "==> repo list:"
  printf '  - %s\n' "${REPO_LIST[@]}"

  # Install play items first
  declare -a failed_play=()
  for name in "${EPM_PLAY_LIST[@]}"; do
    install_with_priority "$name" || failed_play+=("$name")
  done

  # Install repo items
  declare -a failed_repo=()
  for name in "${REPO_LIST[@]}"; do
    install_with_priority "$name" || failed_repo+=("$name")
  done

  echo "---------------------------"
  echo "completed."
  [[ ${#failed_play[@]} -gt 0 ]] && echo "failed (play): ${failed_play[*]}" >&2
  [[ ${#failed_repo[@]} -gt 0 ]] && echo "failed (repo): ${failed_repo[*]}" >&2
}

main "$@"
