#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  build-installer.sh \
    --template-dir <path> \
    --distro <name> \
    --installer-base-url <url>

Environment:
  DX4000_INSTALLER_PASSWORD
    Optional override for the Debian network-console password. If omitted,
    a random secret is generated and written to the output credentials file.

  DX4000_AUTHORIZED_KEYS_URL
    Optional URL to an authorized_keys file for Debian network-console.

  DX4000_BUILD_WORKDIR
    Optional Linux filesystem path to use for temporary build files. If omitted,
    the script builds under a temporary directory in /tmp.
EOF
}

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

cleanup() {
    if command -v mountpoint >/dev/null 2>&1 && mountpoint -q "$efi_mount_dir" 2>/dev/null; then
        umount "$efi_mount_dir" || true
    fi

    rm -rf -- "$efi_mount_dir" "$iso_dir"
    rm -f "$work_initrd" "$work_initrd_gz" "$efi_img"

    if [ "$cleanup_build_root" -eq 1 ]; then
        rm -rf -- "$build_root"
    fi
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "run this script as root or via sudo"
        exit 1
    fi
}

require_commands() {
    local cmd
    for cmd in awk cpio gunzip gzip mktemp mount mountpoint od sed sha256sum umount wget xorriso; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "missing required command: $cmd"
            exit 1
        fi
    done
}

download_installer_assets() {
    local netboot_url="$installer_base_url/dists/$distro/main/installer-amd64/current/images/netboot"
    local images_url="$installer_base_url/dists/$distro/main/installer-amd64/current/images"

    wget -O "$debian_files_dir/mini.iso" "$netboot_url/mini.iso"
    wget -O "$debian_files_dir/SHA256SUMS" "$images_url/SHA256SUMS"
}

verify_installer_iso() {
    local checksum_file="$debian_files_dir/mini.iso.sha256"

    awk '
        $2 == "./netboot/mini.iso" || $2 == "netboot/mini.iso" || $2 == "./mini.iso" || $2 == "mini.iso" {
            print $1 "  mini.iso"
            found = 1
        }
        END {
            exit(found ? 0 : 1)
        }
    ' "$debian_files_dir/SHA256SUMS" > "$checksum_file"

    (
        cd "$debian_files_dir"
        sha256sum -c "$(basename "$checksum_file")"
    )
}

patch_preseed() {
    cp "$template_dir/preseed.cfg" "$payload_dir/preseed.cfg"

    sed -i \
        -e "s/__DX4000_INSTALLER_PASSWORD__/$installer_secret_escaped/g" \
        "$payload_dir/preseed.cfg"

    if [ -n "$authorized_keys_url" ]; then
        sed -i \
            -e "s|^#d-i network-console/authorized_keys_url string .*|d-i network-console/authorized_keys_url string $authorized_keys_url_escaped|" \
            "$payload_dir/preseed.cfg"
    fi
}

write_credentials_file() {
    cat > "$output_dir/dx4000-$distro-installer.credentials.txt" <<EOF
installer_username=installer
installer_secret=$installer_secret
EOF

    if [ -n "$authorized_keys_url" ]; then
        cat >> "$output_dir/dx4000-$distro-installer.credentials.txt" <<EOF
authorized_keys_url=$authorized_keys_url
EOF
    fi
}

template_dir=""
distro=""
installer_base_url=""

while [ $# -gt 0 ]; do
    case "$1" in
        --template-dir)
            template_dir="$2"
            shift 2
            ;;
        --distro)
            distro="$2"
            shift 2
            ;;
        --installer-base-url)
            installer_base_url="$2"
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

if [ -z "$template_dir" ] || [ -z "$distro" ] || [ -z "$installer_base_url" ]; then
    usage
    exit 1
fi

template_dir="$(cd -- "$template_dir" && pwd)"
output_dir="$template_dir/output"
build_root="${DX4000_BUILD_WORKDIR:-}"
cleanup_build_root=0

installer_secret="${DX4000_INSTALLER_PASSWORD:-}"
authorized_keys_url="${DX4000_AUTHORIZED_KEYS_URL:-}"
generated_secret=""

require_root
require_commands

if [ -z "$installer_secret" ]; then
    generated_secret="$(od -An -N 16 -tx1 /dev/urandom | tr -d ' \n')"
    installer_secret="$generated_secret"
fi

installer_secret_escaped="$(escape_sed_replacement "$installer_secret")"
authorized_keys_url_escaped="$(escape_sed_replacement "$authorized_keys_url")"

if [ -z "$build_root" ]; then
    build_root="$(mktemp -d "/tmp/dx4000-$distro-XXXXXX")"
    cleanup_build_root=1
else
    mkdir -p "$build_root"
fi

debian_files_dir="$build_root/debian-files"
payload_dir="$build_root/payload"
iso_dir="$build_root/iso"
efi_mount_dir="$build_root/efimount"
work_initrd="$build_root/initrd"
work_initrd_gz="$build_root/initrd.gz"
efi_img="$build_root/efi.img"

trap cleanup EXIT

mkdir -p "$debian_files_dir" "$output_dir"
rm -rf -- "$payload_dir"
mkdir -p "$payload_dir/source"
rm -rf -- "$debian_files_dir/tmp"

download_installer_assets
verify_installer_iso

patch_preseed
cp "$template_dir/startup.nsh" "$payload_dir/"

xorriso -osirrox on -indev "$debian_files_dir/mini.iso" -extract / "$iso_dir"
cp "$iso_dir/initrd.gz" "$work_initrd_gz"

gunzip "$work_initrd_gz"

(
    cd "$payload_dir"
    find . | cpio -v -H newc -o -A -F "$work_initrd"
)

gzip "$work_initrd"

cp "$work_initrd_gz" "$iso_dir/"
cp "$template_dir/grub.cfg" "$iso_dir/boot/grub/"

rm -f "$output_dir"/*

mkdir -p "$efi_mount_dir"
mount -o loop,ro "$debian_files_dir/mini.iso" "$efi_mount_dir"
cp "$efi_mount_dir/boot/grub/efi.img" "$efi_img"
umount "$efi_mount_dir"
rmdir "$efi_mount_dir"

xorriso -as mkisofs \
    -iso-level 3 \
    -r -V "dx4000-$distro-installer" \
    -J -joliet-long \
    -append_partition 2 0xef "$efi_img" \
    -partition_cyl_align all \
    -o "$output_dir/dx4000-$distro-installer.iso" \
    "$iso_dir/"

write_credentials_file

echo "verified mini.iso with SHA256SUMS"
echo "installer ISO written to $output_dir/dx4000-$distro-installer.iso"
echo "installer SSH credentials saved to $output_dir/dx4000-$distro-installer.credentials.txt"
