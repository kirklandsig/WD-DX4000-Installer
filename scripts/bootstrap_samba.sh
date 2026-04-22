#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  sudo ./scripts/bootstrap_samba.sh --user <linux-user> [--share-name <name>] [--media-root <path>] [--downloads-root <path>]

This script is intended to run on the installed Debian system on the DX4000.
It installs Samba, creates a Windows-friendly media share, creates standard
media directories, and adds the specified Linux user to the shared media group.

Options:
  --user <linux-user>
    Existing Linux account that should own/manage the media share.

  --share-name <name>
    SMB share name. Default: media

  --media-root <path>
    Root path for shared media folders. Default: /srv/media

  --downloads-root <path>
    Root path for downloads. Default: /srv/downloads

Environment:
  SAMBA_PASSWORD
    Optional Samba password for non-interactive setup. If omitted, smbpasswd
    will prompt interactively.
EOF
}

share_name="media"
media_root="/srv/media"
downloads_root="/srv/downloads"
linux_user=""
media_group="media"

while [ $# -gt 0 ]; do
    case "$1" in
        --user)
            linux_user="${2:-}"
            shift 2
            ;;
        --share-name)
            share_name="${2:-}"
            shift 2
            ;;
        --media-root)
            media_root="${2:-}"
            shift 2
            ;;
        --downloads-root)
            downloads_root="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "run this script as root or via sudo"
    exit 1
fi

if [ -z "$linux_user" ]; then
    echo "--user is required"
    usage
    exit 1
fi

if ! getent passwd "$linux_user" >/dev/null 2>&1; then
    echo "linux user does not exist: $linux_user"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y samba

getent group "$media_group" >/dev/null 2>&1 || groupadd "$media_group"
usermod -aG "$media_group" "$linux_user"

install -d -m 2775 -o "$linux_user" -g "$media_group" "$media_root"
install -d -m 2775 -o "$linux_user" -g "$media_group" \
    "$media_root/movies" \
    "$media_root/tv" \
    "$media_root/music" \
    "$media_root/homevideos"
install -d -m 2775 -o "$linux_user" -g "$media_group" "$downloads_root"

if ! grep -q "BEGIN DX4000 SAMBA SHARE" /etc/samba/smb.conf; then
    cat >> /etc/samba/smb.conf <<EOF

# BEGIN DX4000 SAMBA SHARE
[$share_name]
   comment = DX4000 Media Library
   path = $media_root
   browseable = yes
   read only = no
   guest ok = no
   valid users = $linux_user
   force group = $media_group
   create mask = 0664
   directory mask = 2775
# END DX4000 SAMBA SHARE
EOF
fi

if [ -n "${SAMBA_PASSWORD:-}" ]; then
    if pdbedit -L 2>/dev/null | grep -q "^$linux_user:"; then
        printf '%s\n%s\n' "$SAMBA_PASSWORD" "$SAMBA_PASSWORD" | smbpasswd -s "$linux_user"
    else
        printf '%s\n%s\n' "$SAMBA_PASSWORD" "$SAMBA_PASSWORD" | smbpasswd -a -s "$linux_user"
    fi
else
    if pdbedit -L 2>/dev/null | grep -q "^$linux_user:"; then
        smbpasswd "$linux_user"
    else
        smbpasswd -a "$linux_user"
    fi
fi

testparm -s >/dev/null
systemctl enable --now smbd nmbd
systemctl restart smbd nmbd

cat <<EOF
Samba is installed and running.

Windows share:
  \\\\<dx4000-ip>\\$share_name

Media folders:
  $media_root/movies
  $media_root/tv
  $media_root/music
  $media_root/homevideos

Downloads folder:
  $downloads_root
EOF
