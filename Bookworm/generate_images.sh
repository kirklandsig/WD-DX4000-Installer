#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

exec "$repo_root/scripts/build-installer.sh" \
    --template-dir "$script_dir" \
    --distro "bookworm" \
    --installer-base-url "https://deb.debian.org/debian"
