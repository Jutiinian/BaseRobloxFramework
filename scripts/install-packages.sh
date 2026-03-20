#!/bin/sh
# ─────────────────────────────────────────────────────────────
# install-packages.sh
# Installs Wally packages, or regenerates type definitions.
#
# Usage:
#   sh scripts/install-packages.sh [OPTIONS]
#
# Options:
#   --clean     Remove existing Packages/ and ServerPackages/ first
#               (only applies when not using --types)
#   --types     Skip package install and only run wally-package-types
#               Requires sourcemap.json — run process-tree.sh first
#               if it is stale or missing
#   --help, -h  Show this help message
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
print_warning() { printf "${YELLOW}⚠ Warning:${RESET} %s\n" "$1"; }
print_info()    { printf "${CYAN}ℹ${RESET} %s\n" "$1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ── Help ──────────────────────────────────────────────────────
show_help() {
    printf "%b\n" "$(cat << EOF
${BOLD}install-packages.sh${RESET} — Install Wally packages or regenerate types

${BOLD}USAGE${RESET}
    sh scripts/install-packages.sh [OPTIONS]

${BOLD}OPTIONS${RESET}
    --clean     Remove Packages/ and ServerPackages/ before installing
                (ignored when --types is set)
    --types     Skip package install — only run wally-package-types
                Requires an up-to-date sourcemap.json
    --help, -h  Show this help

${BOLD}EXAMPLES${RESET}
    # Install packages
    sh scripts/install-packages.sh

    # Clean install
    sh scripts/install-packages.sh --clean

    # Regenerate types only (packages already installed)
    sh scripts/install-packages.sh --types

${BOLD}REQUIREMENTS${RESET}
    - wally
    - wally-package-types (only with --types)

EOF
)"
}

# ── Parse args ────────────────────────────────────────────────
CLEAN=false
TYPES_ONLY=false

while [ $# -gt 0 ]; do
    case "$1" in
        --clean)    CLEAN=true ;;
        --types)    TYPES_ONLY=true ;;
        --help|-h)  show_help; exit 0 ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
    shift
done

cd "$(dirname "$0")/.."

# ── Types only mode ───────────────────────────────────────────
if [ "$TYPES_ONLY" = "true" ]; then
    if ! command_exists wally-package-types; then
        print_error "wally-package-types is not installed"
        exit 1
    fi

    if [ ! -f "sourcemap.json" ]; then
        print_error "sourcemap.json not found — run process-tree.sh first"
        exit 1
    fi

    for pkg_dir in Packages ServerPackages; do
        if [ -d "$pkg_dir" ]; then
            print_step "Generating types for $pkg_dir/..."
            if wally-package-types --sourcemap sourcemap.json "$pkg_dir/"; then
                print_success "Types generated for $pkg_dir/"
            else
                print_warning "Type generation failed for $pkg_dir/"
            fi
        fi
    done

    echo ""
    print_success "Done!"
    exit 0
fi

# ── Install mode ──────────────────────────────────────────────
if ! command_exists wally; then
    print_error "wally is not installed"
    print_info "See: https://github.com/UpliftGames/wally"
    exit 1
fi

if [ "$CLEAN" = "true" ]; then
    print_step "Cleaning existing packages..."
    for dir in Packages ServerPackages; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            print_success "Removed $dir/"
        fi
    done
    echo ""
fi

print_step "Installing Wally packages..."
if wally install; then
    print_success "Wally packages installed"
else
    print_error "wally install failed"
    exit 1
fi

echo ""
print_success "Done!"