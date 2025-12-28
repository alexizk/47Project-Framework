#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log(){ echo "[start] $*"; }

if command -v pwsh >/dev/null 2>&1; then
  log "pwsh found: $(pwsh --version)"
else
  log "pwsh not found."
  if [[ -f "$ROOT/tools/install_dependencies.sh" ]]; then
    log "Attempting to install dependencies (requires sudo, Debian/Ubuntu)."
    sudo bash "$ROOT/tools/install_dependencies.sh"
  else
    log "No installer found. Install PowerShell 7+ then retry."
    exit 1
  fi
fi

# Optional: ensure Pester for contributors who want to run tests
if [[ "${INSTALL_TEST_DEPS:-0}" == "1" ]]; then
  log "Installing test dependencies (Pester)..."
  pwsh -NoLogo -NoProfile -File "$ROOT/tools/install_pester.ps1" -PreferVendor ${OFFLINE_ONLY:+-OfflineOnly}
fi

log "Launching Framework..."
exec pwsh -NoLogo -NoProfile -File "$ROOT/47Project.Framework.Launch.ps1" "$@"
