#!/bin/bash
# Apply the device's fixes to the synced TWRP source tree (idempotent).
#   scripts/source-patches/<path with / replaced by _>.patch -> <path>
# usage: apply-source-patches.sh <twrp source dir>
set -euo pipefail
SRC=$(realpath "$1")
DIR="$(dirname "$(realpath "$0")")/source-patches"
for patch in "$DIR"/*.patch; do
    [ -e "$patch" ] || continue
    proj=$(basename "$patch" .patch | tr _ /)
    if git -C "$SRC/$proj" apply --reverse --check "$patch" 2>/dev/null; then
        echo "already applied: $(basename "$patch") -> $proj"
    else
        git -C "$SRC/$proj" apply "$patch"
        echo "applied: $(basename "$patch") -> $proj"
    fi
done
