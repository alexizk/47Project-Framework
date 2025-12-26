#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

log() { echo "[install_dependencies] $*"; }

if [[ $EUID -ne 0 ]]; then
  log "Please run as root (sudo)."
  exit 1
fi

apt_update() {
  log "apt-get update (with retries)"
  apt-get update -o Acquire::Retries=5 -o Acquire::http::Timeout="30" -o Acquire::https::Timeout="30"
}

ensure_pkg() {
  local pkgs=("$@")
  apt_update
  apt-get install -y --no-install-recommends "${pkgs[@]}"
}

install_powershell() {
  if command -v pwsh >/dev/null 2>&1; then
    log "PowerShell already installed: $(pwsh --version)"
    return
  fi

  log "Installing PowerShell 7..."
  ensure_pkg ca-certificates curl gnupg apt-transport-https lsb-release

  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg
  local codename
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  # Default to jammy if empty (Ubuntu 22.04) for compatibility; adjust if needed.
  if [[ -z "$codename" ]]; then codename="jammy"; fi

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/${VERSION_ID:-22.04}/prod ${codename} main" \
    > /etc/apt/sources.list.d/microsoft.list

  apt_update
  apt-get install -y --no-install-recommends powershell
  log "Installed: $(pwsh --version)"
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version)"
    return
  fi

  log "Installing Docker Engine..."
  ensure_pkg ca-certificates curl gnupg

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > /usr/share/keyrings/docker.gpg
  local codename
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  if [[ -z "$codename" ]]; then codename="jammy"; fi

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt_update
  apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  if command -v systemctl >/dev/null 2>&1; then
    log "Enabling/starting docker service (systemd)"
    systemctl enable docker || true
    systemctl start docker || true
  fi

  log "Installed: $(docker --version)"
}

main() {
  install_powershell
  install_docker

  log "Done."
  log "Verify:"
  log "  pwsh --version"
  log "  docker --version"
}

main "$@"
