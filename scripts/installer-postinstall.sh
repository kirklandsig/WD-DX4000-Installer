#!/bin/sh
set -u

log_file="/var/log/dx4000-postinstall.log"
startup_src="/startup.nsh"
target_esp="/target/boot/efi"
mounted_esp=0

log() {
    printf '%s\n' "$*" >> "$log_file"
}

copy_startup() {
    if cp "$startup_src" "$target_esp/startup.nsh"; then
        sync
        log "copied startup.nsh to $target_esp/startup.nsh"
        return 0
    fi

    log "failed to copy startup.nsh to $target_esp/startup.nsh"
    return 1
}

is_mounted() {
    awk -v target="$1" '
        $2 == target {
            found = 1
            exit 0
        }
        END {
            exit(found ? 0 : 1)
        }
    ' /proc/mounts
}

resolve_esp_device() {
    esp_spec="$(
        awk '$2 == "/boot/efi" { print $1; exit }' /target/etc/fstab 2>/dev/null
    )"

    case "$esp_spec" in
        UUID=*)
            blkid -U "${esp_spec#UUID=}" 2>/dev/null || true
            ;;
        /dev/*)
            printf '%s\n' "$esp_spec"
            ;;
    esac
}

if [ ! -f "$startup_src" ]; then
    log "startup.nsh not found in installer environment"
    exit 0
fi

modprobe vfat 2>/dev/null || true
if command -v disk-detect >/dev/null 2>&1; then
    disk-detect 2>/dev/null || true
fi
mkdir -p "$target_esp"

if is_mounted "$target_esp"; then
    copy_startup
    exit 0
fi

esp_device="$(resolve_esp_device)"

if [ -n "$esp_device" ]; then
    if mount -t vfat "$esp_device" "$target_esp"; then
        mounted_esp=1
        log "mounted ESP $esp_device on $target_esp"
        copy_startup || true
    else
        log "failed to mount ESP $esp_device on $target_esp"
    fi
else
    log "could not resolve /boot/efi device from /target/etc/fstab"
fi

if [ "$mounted_esp" -eq 1 ]; then
    if umount "$target_esp"; then
        log "unmounted $target_esp"
    else
        log "failed to unmount $target_esp"
    fi
fi

exit 0
