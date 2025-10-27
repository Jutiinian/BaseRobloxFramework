#!/bin/sh

# ─────────────────────────────────────────────────────────────
# install-packages.sh
# Installs wally packages and then runs wally-package-types
# Usage:
#   sh scripts/install-packages.sh
# ─────────────────────────────────────────────────────────────

# Exit if any command fails
set -e

# Move to project root (directory of this script → one level up)
cd "$(dirname "$0")/.."

echo "Installing Wally Dependecies..."
wally install

echo "Rojo sourcemap..."
rojo sourcemap default.project.json --output sourcemap.json

echo "Package Types for Packages..."
wally-package-types -s sourcemap.json Packages/

echo "Package Types for Server Packages..."
wally-package-types -s sourcemap.json ServerPackages/

echo "✅ Done!"