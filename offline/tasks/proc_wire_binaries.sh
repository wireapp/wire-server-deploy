#!/usr/bin/env bash
set -euo pipefail

echo "Processing wire binaries..."

mkdir -p binaries
install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* binaries/
tar cf binaries.tar binaries
rm -r binaries
