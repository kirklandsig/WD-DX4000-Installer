#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  sudo ./scripts/bootstrap_casaos.sh

This script is intended to run on the installed Debian system on the DX4000.
It installs CasaOS using IceWhale's official installer. CasaOS is an optional
management UI layered on top of Debian, not a replacement for Plex or Samba.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "run this script as root or via sudo"
    exit 1
fi

for cmd in apt-get curl bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing required command: $cmd"
        exit 1
    fi
done

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl ca-certificates
curl -fsSL https://get.casaos.io | bash

cat <<'EOF'
CasaOS installation complete.

Next steps:
1. Open http://<dx4000-ip>/
2. Finish CasaOS onboarding in the browser
3. Keep Plex and Samba as the underlying media services

If you need to remove CasaOS later, run:
  casaos-uninstall
EOF
