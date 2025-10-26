#!/bin/sh

# ─────────────────────────────────────────────────────────────
# process-tree.sh
# Runs generateRojoTree.js then creates new sourcemap.
# Usage:
#   sh scripts/process-tree.sh
# ─────────────────────────────────────────────────────────────

# Exit if any command fails
set -e

# Move to project root (directory of this script → one level up)
cd "$(dirname "$0")/.."

echo "🔧 Generating Rojo tree..."
node scripts/generateRojoTree.js

echo "🌳 Rojo sourcemap..."
rojo sourcemap default.project.json --output sourcemap.json

echo "✅ Done!"