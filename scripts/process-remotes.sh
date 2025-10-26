#!/bin/bash

# ─────────────────────────────────────────────────────────────
# process-remotes.sh
# Runs Zap against every .zap config in the zapConfigs folder.
# Usage:
#   sh scripts/process-remotes.sh
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../zapConfigs"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "❌ Error: '$CONFIG_DIR' directory not found."
  exit 1
fi

echo "🔍 Scanning zapConfigs/ for .zap files..."

for file in "$CONFIG_DIR"/*.zap; do
  if [ ! -e "$file" ]; then
    echo "⚠️  No .zap files found in zapConfigs/"
    exit 0
  fi

  echo "⚙️  Processing: $file"
  zap "$file" || {
    echo "❌ Error processing $file — stopping."
    exit 1
  }
done

echo "✅ All remotes successfully processed!"