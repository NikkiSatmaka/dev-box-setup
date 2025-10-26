#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091

set -euo pipefail

HOMEBREW_INSTALL_SCRIPT="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
SYSTEM_HOSTNAME="$(uname -n | sed 's|.local||g')"
SYSTEM_TYPE="$(uname -s)"
PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:${PATH}"; export PATH

SKIP_BOOTSTRAP=""
SKIP_HOMEBREW_LINUX=""

usage() {
  echo "install: system and Ansible bootstrap script"
  echo
  echo "USAGE: bash install.sh [OPTIONS]"
  echo
  echo "OPTIONS:"
  echo "  -h Show help and exit"
  echo "  -r Resume an interrupted Ansible run"
  echo "  -w Skip Homebrew install on Linux (noop for macOS)"
  echo
}

# ----------------------------------------
# Bootstrap funcions
# ----------------------------------------

install_homebrew() {
  case "$ID" in
    fedora) sudo dnf install -y @development-tools procps-ng curl file ;;
    debian|ubuntu|linuxmint) sudo apt-get install -y build-essential procps curl file git ;;
    macos) sudo softwareupdate --install-rosetta ;;
  esac
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL $HOMEBREW_INSTALL_SCRIPT)"
}

bootstrap_mac() {
  pgrep caffeinate >/dev/null || (caffeinate -d -i -m -u &)
  sudo scutil --set HostName "$SYSTEM_HOSTNAME"
  ID=macos install_homebrew
}

bootstrap_linux() {
  if sudo systemctl is-active packagekit.service --quiet; then
    sudo systemctl stop packagekit
  fi

  sudo hostnamectl set-hostname "$SYSTEM_HOSTNAME"
  . /etc/os-release

  case "$ID" in
    fedora)
      sudo dnf clean all
      sudo dnf makecache
      ;;
    debian|ubuntu|linuxmint)
      sudo apt-get clean
      sudo apt-get update
      ;;
    *) exit 1;;
  esac

  case $(uname -m) in (aarch*|arm*)
    SKIP_HOMEBREW_LINUX=1 ;;  # https://github.com/Homebrew/brew/issues/19208
  esac

  if [ -z "$SKIP_HOMEBREW_LINUX" ]; then
    install_homebrew
  fi
}

# ----------------------------------------
# Main functions
# ----------------------------------------

main_setup_venv() {
  export ANSIBLE_PYTHON_INTERPRETER=".venv/bin/python3"
  export ANSIBLE_HOME="${HOME}/.config/ansible"

  git pull

  uv sync --locked
  . .venv/bin/activate
}

# ----------------------------------------
# Main script
# ----------------------------------------

while getopts "hrwf" opt; do
  case "$opt" in
    h) usage; exit 0 ;;
    r) SKIP_BOOTSTRAP=1 ;;
    w) SKIP_HOMEBREW_LINUX=1 ;;
    *) usage; exit 1 ;;
  esac
done

if [ -z "$SKIP_BOOTSTRAP" ]; then
  printf "Enter hostname [%s]: " "$SYSTEM_HOSTNAME"
  read -r read_system_hostname
  SYSTEM_HOSTNAME="${read_system_hostname:-${SYSTEM_HOSTNAME}}"

  case $SYSTEM_TYPE in
    Darwin) bootstrap_mac ;;
    Linux) bootstrap_linux ;;
    *) exit 1 ;;
  esac
fi

if [ ! -e "${HOME}/.config/ansible" ]; then
  mkdir "${HOME}/.config/ansible"
fi

main_setup_venv
