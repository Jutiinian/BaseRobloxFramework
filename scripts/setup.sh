#!/bin/sh
# ─────────────────────────────────────────────────────────────
# setup.sh
# Full project setup — runs every step in the correct order.
#
# Step order:
#   1. Install Rokit tools
#   2. Generate Rojo project tree  (default.project.json)
#   3. Process .zap remotes        (network remote code)
#   4. Install Wally packages      (Packages/, ServerPackages/)
#   5. Generate sourcemap          (sourcemap.json)
#   6. Generate type definitions
#
# Each step is independent. This script is the only place
# where ordering is enforced — individual scripts stay simple.
#
# Usage:
#   sh scripts/setup.sh [OPTIONS]
#
# Options:
#   --clean           Remove Packages/, ServerPackages/, sourcemap.json first
#   --skip-remotes    Skip .zap processing
#   --skip-types      Skip type definition generation
#   --skip-tree       Skip project tree generation (use existing default.project.json)
#   --help, -h        Show this help message
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
DIM='\033[2m'

if [ ! -t 1 ] || [ "${NO_COLOR:-}" = "1" ]; then
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' RESET='' BOLD='' DIM=''
fi

# ── Helpers ───────────────────────────────────────────────────
print_header() {
    echo ""
    printf "${BLUE}${BOLD}━━━ %s ━━━${RESET}\n" "$1"
}

print_step() {
    printf "${BLUE}${BOLD}▶${RESET} ${BOLD}%s${RESET}\n" "$1"
}

print_success() {
    printf "${GREEN}✓${RESET} %s\n" "$1"
}

print_error() {
    printf "${RED}✗ Error:${RESET} %s\n" "$1" >&2
}

print_warning() {
    printf "${YELLOW}⚠ Warning:${RESET} %s\n" "$1"
}

print_info() {
    printf "${CYAN}ℹ${RESET} %s\n" "$1"
}

print_dim() {
    printf "${DIM}%s${RESET}\n" "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ── Dependency check ──────────────────────────────────────────
check_dependencies() {
    local missing=""

    command_exists node  || missing="${missing}  - node\n"
    command_exists rojo  || missing="${missing}  - rojo\n"
    command_exists wally || missing="${missing}  - wally\n"

    if [ "$SKIP_TYPES" = "false" ] && ! command_exists wally-package-types; then
        missing="${missing}  - wally-package-types (skip with --skip-types)\n"
    fi

    if [ -n "$missing" ]; then
        print_error "Missing required tools:"
        printf "%b" "$missing"
        print_dim "  Tip: run 'rokit install' to install project tools."
        exit 1
    fi
}

# ── Help ──────────────────────────────────────────────────────
show_help() {
    printf "%b\n" "$(cat << EOF
${BOLD}setup.sh${RESET} — Full project setup

${BOLD}STEPS (always run in this order)${RESET}
    1. Install Rokit tools
    2. Generate Rojo project tree   →  default.project.json
    3. Process .zap remotes         →  network remote code
    4. Install Wally packages       →  Packages/ ServerPackages/
    5. Generate Rojo sourcemap      →  sourcemap.json
    6. Generate type definitions

${BOLD}USAGE${RESET}
    sh scripts/setup.sh [OPTIONS]

${BOLD}OPTIONS${RESET}
    --clean           Remove Packages/, ServerPackages/, sourcemap.json first
    --skip-remotes    Skip .zap processing (step 3)
    --skip-types      Skip type definition generation (step 6)
    --skip-tree       Skip tree generation (step 2) — reuse default.project.json
    --help, -h        Show this help

${BOLD}EXAMPLES${RESET}
    # First-time setup
    sh scripts/setup.sh

    # Clean reinstall
    sh scripts/setup.sh --clean

    # Regenerate tree + sourcemap only (packages already installed)
    sh scripts/process-tree.sh

    # Install / update packages only (tree already up to date)
    sh scripts/install-packages.sh

EOF
)"
}

# ── Parse args ────────────────────────────────────────────────
CLEAN=false
SKIP_TYPES=false
SKIP_TREE=false
SKIP_REMOTES=false

while [ $# -gt 0 ]; do
    case "$1" in
        --clean)          CLEAN=true ;;
        --skip-types)     SKIP_TYPES=true ;;
        --skip-tree)      SKIP_TREE=true ;;
        --skip-remotes)   SKIP_REMOTES=true ;;
        --help|-h)        show_help; exit 0 ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
    shift
done

# ── Setup ─────────────────────────────────────────────────────
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

printf "${BOLD}Game-Framework Setup${RESET}\n"
print_dim "Project root: $PROJECT_ROOT"
echo ""

check_dependencies

# ─────────────────────────────────────────────────────────────
# Step 0 — Clean (optional)
# ─────────────────────────────────────────────────────────────
if [ "$CLEAN" = "true" ]; then
    print_header "Clean"
    for target in Packages ServerPackages sourcemap.json; do
        if [ -e "$target" ]; then
            rm -rf "$target"
            print_success "Removed $target"
        fi
    done
fi

# ─────────────────────────────────────────────────────────────
# Step 1 — Rokit tools
# ─────────────────────────────────────────────────────────────
if command_exists rokit && [ -f "rokit.toml" ]; then
    print_header "Step 1 — Rokit Tools"
    if rokit install; then
        print_success "Rokit tools installed"
    else
        print_warning "rokit install failed — continuing anyway"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Step 2 — Generate Rojo project tree
# ─────────────────────────────────────────────────────────────
print_header "Step 2 — Rojo Project Tree"

if [ "$SKIP_TREE" = "true" ]; then
    if [ ! -f "default.project.json" ]; then
        print_error "--skip-tree was set but default.project.json does not exist"
        exit 1
    fi
    print_info "Skipping tree generation (--skip-tree)"
else
    if node scripts/generateRojoTree.js; then
        print_success "default.project.json generated"
    else
        print_error "Tree generation failed"
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────────
# Step 3 — Process .zap remotes
# ─────────────────────────────────────────────────────────────
print_header "Step 3 — Remotes"

if [ "$SKIP_REMOTES" = "true" ]; then
    print_info "Skipping remote processing (--skip-remotes)"
elif ! command_exists zap; then
    print_warning "zap not found — skipping remote processing"
    print_dim "  Install with: rokit add red-blox/zap"
else
    if sh scripts/process-remotes.sh; then
        print_success "Remotes processed"
    else
        print_error "Remote processing failed"
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────────
# Step 4 — Install Wally packages
# ─────────────────────────────────────────────────────────────
print_header "Step 4 — Wally Packages"

if wally install; then
    print_success "Wally packages installed"
else
    print_error "wally install failed"
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Step 5 — Generate sourcemap
# ─────────────────────────────────────────────────────────────
print_header "Step 5 — Sourcemap"

if rojo sourcemap default.project.json --output sourcemap.json; then
    print_success "sourcemap.json generated"
else
    print_error "Sourcemap generation failed"
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Step 6 — Type definitions
# ─────────────────────────────────────────────────────────────
print_header "Step 6 — Type Definitions"

if [ "$SKIP_TYPES" = "true" ]; then
    print_info "Skipping type generation (--skip-types)"
else
    type_generated=false

    for pkg_dir in Packages ServerPackages; do
        if [ -d "$pkg_dir" ]; then
            print_info "Processing $pkg_dir/..."
            if wally-package-types --sourcemap sourcemap.json "$pkg_dir/"; then
                print_success "Types generated for $pkg_dir/"
                type_generated=true
            else
                print_warning "Type generation failed for $pkg_dir/"
            fi
        fi
    done

    if [ "$type_generated" = "false" ]; then
        print_warning "No package directories found — skipping type generation"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}✅  Setup complete!${RESET}\n"
echo ""
print_dim "To serve with Rojo:      rojo serve"
print_dim "To rebuild the tree:     sh scripts/process-tree.sh"
print_dim "To reprocess remotes:    sh scripts/process-remotes.sh"
print_dim "To update packages:      sh scripts/install-packages.sh"