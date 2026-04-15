#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  sudo ./scripts/bootstrap_plex.sh

This script is intended to run on the installed Debian system on the DX4000.
It adds Plex's official apt repository, installs Plex Media Server, and
enables the systemd service.
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

for cmd in apt-get curl gpg install systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing required command: $cmd"
        exit 1
    fi
done

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl gnupg2

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://downloads.plex.tv/plex-keys/PlexSign.v2.key \
    | gpg --yes --dearmor -o /etc/apt/keyrings/plexmediaserver.v2.gpg

cat > /etc/apt/sources.list.d/plexmediaserver.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/plexmediaserver.v2.gpg] https://repo.plex.tv/deb/ public main
EOF

apt-get update
apt-get install -y plexmediaserver
systemctl enable --now plexmediaserver

cat <<'EOF'
Plex Media Server is installed and running.

Next steps:
1. Open http://<dx4000-ip>:32400/web
2. Sign in with your Plex account
3. Point Plex at your media folders
4. Keep clients on Original quality to favor Direct Play / Direct Stream
EOF
