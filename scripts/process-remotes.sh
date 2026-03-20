#!/bin/sh
# ─────────────────────────────────────────────────────────────
# process-remotes.sh
# Processes all .zap files found under src/features/ and src/services/.
# Directory matching is case-insensitive.
#
# Usage:
#   sh scripts/process-remotes.sh [OPTIONS]
#
# Options:
#   --verbose     Show full zap output for each file
#   --dry-run     Show which files would be processed without running zap
#   --help, -h    Show this help message
# ─────────────────────────────────────────────────────────────

set -e
set -u

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

if [ ! -t 1 ] || [ "${NO_COLOR:-}" = "1" ]; then
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' RESET='' BOLD='' DIM=''
fi

# ── Helpers ───────────────────────────────────────────────────
print_step()       { printf "${BLUE}${BOLD}▶${RESET} ${BOLD}%s${RESET}\n" "$1"; }
print_success()    { printf "${GREEN}✓${RESET} %s\n" "$1"; }
print_error()      { printf "${RED}✗ Error:${RESET} %s\n" "$1" >&2; }
print_warning()    { printf "${YELLOW}⚠ Warning:${RESET} %s\n" "$1"; }
print_info()       { printf "${CYAN}ℹ${RESET} %s\n" "$1"; }
print_dim()        { printf "${DIM}%s${RESET}\n" "$1"; }
print_processing() { printf "${MAGENTA}⚙${RESET}  Processing: ${BOLD}%s${RESET}\n" "$1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ── Help ──────────────────────────────────────────────────────
show_help() {
    printf "%b\n" "$(cat << EOF
${BOLD}process-remotes.sh${RESET} — Run zap on all .zap network definition files

${BOLD}DESCRIPTION${RESET}
    Finds every .zap file under src/features/ and src/services/ (any casing)
    and runs zap on each one, generating the network remote code for your
    features and services.

    Stops immediately on the first failure — broken network definitions
    should always be fixed before continuing.

${BOLD}USAGE${RESET}
    sh scripts/process-remotes.sh [OPTIONS]

${BOLD}OPTIONS${RESET}
    --verbose     Show full zap output for each file
    --dry-run     List files that would be processed without running zap
    --help, -h    Show this help

${BOLD}EXPECTED STRUCTURE${RESET}
    src/features/FeatureName/FeatureName.zap
    src/services/ServiceName/ServiceName.zap
    (any casing of features/ or services/ is accepted)

${BOLD}REQUIREMENTS${RESET}
    - zap   (rokit add red-blox/zap)

EOF
)"
}

# ── Dependency check ──────────────────────────────────────────
check_dependencies() {
    if ! command_exists zap; then
        print_error "zap is not installed"
        print_info "Install with: rokit add red-blox/zap"
        exit 1
    fi
}

# ── Find all .zap files ───────────────────────────────────────
# Scans every directory under src/ whose lowercase name is
# "features" or "services", then collects all .zap files inside.
find_zap_files() {
    local src_dir="$1"
    local results=""

    for dir in "$src_dir"/*/; do
        [ -d "$dir" ] || continue

        lower=$(basename "$dir" | tr '[:upper:]' '[:lower:]')
        if [ "$lower" = "features" ] || [ "$lower" = "services" ]; then
            found=$(find "$dir" -type f -name "*.zap" 2>/dev/null || true)
            if [ -n "$found" ]; then
                results="${results:+$results
}$found"
            fi
        fi
    done

    printf '%s' "$results"
}

# ── Process a single .zap file ────────────────────────────────
process_zap_file() {
    local file="$1"
    local rel
    rel=$(printf '%s' "$file" | sed "s|${PROJECT_ROOT}/||")

    print_processing "$rel"

    if [ "$DRY_RUN" = "true" ]; then
        print_dim "  [dry run — would execute: zap \"$file\"]"
        return 0
    fi

    if [ "$VERBOSE" = "true" ]; then
        zap "$file"
    else
        output=$(zap "$file" 2>&1) || {
            print_error "Failed: $rel"
            printf '%s\n' "$output" >&2
            return 1
        }
    fi

    print_success "Processed: $rel"
}

# ── Parse args ────────────────────────────────────────────────
VERBOSE=false
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        --verbose|-v) VERBOSE=true ;;
        --dry-run)    DRY_RUN=true ;;
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
PROJECT_ROOT=$(pwd)
SRC_DIR="${PROJECT_ROOT}/src"

if [ ! -d "$SRC_DIR" ]; then
    print_error "src/ directory not found: $SRC_DIR"
    exit 1
fi

check_dependencies

zap_files=$(find_zap_files "$SRC_DIR")

if [ -z "$zap_files" ]; then
    print_warning "No .zap files found under src/features/ or src/services/"
    print_dim "  Expected: src/features/FeatureName/FeatureName.zap"
    print_dim "            src/services/ServiceName/ServiceName.zap"
    exit 0
fi

file_count=$(printf '%s\n' "$zap_files" | grep -c . || true)

if [ "$DRY_RUN" = "true" ]; then
    print_step "Dry run — would process ${file_count} file(s):"
else
    print_step "Found ${file_count} .zap file(s)"
fi
echo ""

printf '%s\n' "$zap_files" | while IFS= read -r file; do
    [ -n "$file" ] || continue
    process_zap_file "$file"
done

echo ""
if [ "$DRY_RUN" = "false" ]; then
    print_success "All remotes processed!"
else
    print_info "Dry run complete — no files were changed"
fi