#!/bin/sh
# ─────────────────────────────────────────────────────────────
# process-tree.sh
# Regenerates the Rojo project tree and sourcemap.
# Run this whenever you add/remove/rename source files.
#
# Does NOT install Wally packages or regenerate types.
# wally-package-types mutates Packages/ in place — running it
# a second time on already-mutated files causes errors. Types
# must only run right after a fresh wally install.
# Use install-packages.sh or setup.sh for that.
#
# Usage:
#   sh scripts/process-tree.sh [OPTIONS]
#
# Options:
#   --skip-tree     Skip generateRojoTree.js (reuse existing default.project.json)
#   --skip-map      Skip sourcemap generation
#   --help, -h      Show this help message
# ─────────────────────────────────────────────────────────────

set -e
set -u

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'
BOLD='\033[1m'

if [ ! -t 1 ] || [ "${NO_COLOR:-}" = "1" ]; then
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' RESET='' BOLD=''
fi

# ── Helpers ───────────────────────────────────────────────────
print_step()    { printf "${BLUE}${BOLD}▶${RESET} ${BOLD}%s${RESET}\n" "$1"; }
print_success() { printf "${GREEN}✓${RESET} %s\n" "$1"; }
print_error()   { printf "${RED}✗ Error:${RESET} %s\n" "$1" >&2; }
print_info()    { printf "${CYAN}ℹ${RESET} %s\n" "$1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ── Help ──────────────────────────────────────────────────────
show_help() {
    printf "%b\n" "$(cat << EOF
${BOLD}process-tree.sh${RESET} — Rebuild Rojo tree and sourcemap

${BOLD}DESCRIPTION${RESET}
    Runs the two steps needed after changing source files:
      1. Generate default.project.json  (generateRojoTree.js)
      2. Generate sourcemap.json        (rojo sourcemap)

    Type generation is intentionally excluded. wally-package-types mutates
    Packages/ in place — running it again on already-mutated files breaks
    them. Types must only run right after a fresh wally install.
    Use install-packages.sh or setup.sh for that.

${BOLD}USAGE${RESET}
    sh scripts/process-tree.sh [OPTIONS]

${BOLD}OPTIONS${RESET}
    --skip-tree     Skip step 1 (reuse existing default.project.json)
    --skip-map      Skip step 2
    --help, -h      Show this help

${BOLD}REQUIREMENTS${RESET}
    - node
    - rojo

EOF
)"
}

# ── Parse args ────────────────────────────────────────────────
SKIP_TREE=false
SKIP_MAP=false

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-tree)  SKIP_TREE=true ;;
        --skip-map)   SKIP_MAP=true ;;
        --help|-h)    show_help; exit 0 ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
    shift
done

# ── Main ──────────────────────────────────────────────────────
cd "$(dirname "$0")/.."

# ── Step 1 — Project tree ─────────────────────────────────────
if [ "$SKIP_TREE" = "false" ]; then
    if ! command_exists node; then
        print_error "node is not installed"
        exit 1
    fi

    print_step "Generating Rojo project tree..."
    if node scripts/generateRojoTree.js; then
        print_success "default.project.json generated"
    else
        print_error "Tree generation failed"
        exit 1
    fi
    echo ""
else
    if [ ! -f "default.project.json" ]; then
        print_error "--skip-tree was set but default.project.json does not exist"
        exit 1
    fi
    print_info "Skipping tree generation (--skip-tree)"
fi

# ── Step 2 — Sourcemap ────────────────────────────────────────
if [ "$SKIP_MAP" = "false" ]; then
    if ! command_exists rojo; then
        print_error "rojo is not installed"
        exit 1
    fi

    print_step "Generating sourcemap..."
    if rojo sourcemap default.project.json --output sourcemap.json; then
        print_success "sourcemap.json generated"
    else
        print_error "Sourcemap generation failed"
        exit 1
    fi
    echo ""
else
    print_info "Skipping sourcemap generation (--skip-map)"
fi

print_success "Tree processing complete!"