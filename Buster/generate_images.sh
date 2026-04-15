#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

exec "$repo_root/scripts/build-installer.sh" \
    --template-dir "$script_dir" \
    --distro "buster" \
    --installer-base-url "https://archive.debian.org/debian"
