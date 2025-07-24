#!/bin/bash

# boomslang-install.sh - Install Amazon Q Developer CLI standards
# Pre-configured by organization maintainers for zero-config installation

set -e

# Script configuration - MAINTAINERS: Update these values for your organization
SCRIPT_VERSION="0.1.0"
ORG_REPO_URL="gitlab.example.com/org/amazonq-standards"  # Set by maintainer for zero-config installation
ORG_BRANCH="main"

# Runtime configuration
TARGET_DIR="$HOME/.amazonq/rules"
INSTALL_MARKER="$TARGET_DIR/.boomslang-installed"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Command line overrides (optional)
REPO_URL=""
BRANCH=""
DRY_RUN=false
UNINSTALL=false
FORCE=false
QUIET=false

usage() {
    cat << EOF
${BOLD}Amazon Q Developer CLI Standards Installer${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}ZERO-CONFIG INSTALLATION:${NC}
    $0                          # Install using pre-configured settings

${BOLD}OPTIONS (for overrides):${NC}
    -r, --repo URL          Override repository URL
    -b, --branch BRANCH     Override git branch
    -d, --dry-run          Show what would be done without making changes
    -u, --uninstall        Remove installed standards
    -f, --force            Force installation/removal without prompts
    -q, --quiet            Suppress non-error output
    -h, --help             Show this help message
    -v, --version          Show version information

${BOLD}EXAMPLES:${NC}
    # Simple installation (recommended)
    $0

    # Dry run to see what would happen
    $0 --dry-run

    # Override repository (for testing)
    $0 --repo gitlab.acme.com/devtools/amazonq-standards-dev

    # Uninstall
    $0 --uninstall

EOF
}

log() {
    if [ "$QUIET" = false ]; then
        echo -e "$1"
    fi
}

error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}" >&2
}

success() {
    log "${GREEN}✅ $1${NC}"
}

info() {
    log "${BLUE}ℹ️  $1${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO_URL="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -u|--uninstall)
            UNINSTALL=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -v|--version)
            echo "Amazon Q Standards Installer v$SCRIPT_VERSION"
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

detect_repository() {
    local detected_repo=""
    
    # Try to detect from git remote if we're in a git repository
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        detected_repo=$(git remote get-url origin 2>/dev/null || echo "")
        if [ -n "$detected_repo" ]; then
            info "Auto-detected repository: $detected_repo"
            echo "$detected_repo"
            return 0
        fi
    fi
    
    # If ORG_REPO_URL is set by maintainer, use that
    if [ -n "$ORG_REPO_URL" ]; then
        info "Using pre-configured repository: $ORG_REPO_URL"
        echo "$ORG_REPO_URL"
        return 0
    fi
    
    return 1
}

load_config() {
    local repo="$1"
    local branch="$2"
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    info "Loading configuration from repository..."
    
    # Download just the config file
    if ! download_repo "$repo" "$branch" "$temp_dir"; then
        error "Failed to download repository for configuration"
        return 1
    fi
    
    local config_file="$temp_dir/install-config.json"
    if [ ! -f "$config_file" ]; then
        warn "No install-config.json found, using defaults"
        return 0
    fi
    
    # Parse configuration with jq if available
    if command -v jq >/dev/null 2>&1; then
        local repo_url=$(jq -r '.repository.url // empty' "$config_file" 2>/dev/null)
        local default_branch=$(jq -r '.repository.default_branch // empty' "$config_file" 2>/dev/null)
        local org_name=$(jq -r '.organization.name // empty' "$config_file" 2>/dev/null)
        
        if [ -n "$repo_url" ] && [ -z "$REPO_URL" ]; then
            REPO_URL="$repo_url"
            info "Config: Repository URL set to $REPO_URL"
        fi
        
        if [ -n "$default_branch" ] && [ -z "$BRANCH" ]; then
            BRANCH="$default_branch"
            info "Config: Branch set to $BRANCH"
        fi
        
        if [ -n "$org_name" ]; then
            info "Config: Installing standards for $org_name"
        fi
    else
        warn "jq not found, using basic configuration parsing"
    fi
}

check_dependencies() {
    local missing_deps=()
    
    # Check for required tools
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    # Check for glab (preferred) or ssh
    if ! command -v glab >/dev/null 2>&1 && ! command -v ssh >/dev/null 2>&1; then
        missing_deps+=("glab or ssh")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
}

check_glab_auth() {
    if command -v glab >/dev/null 2>&1; then
        if glab auth status >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

download_with_glab() {
    local repo="$1"
    local branch="$2"
    local temp_dir="$3"
    
    info "Downloading using glab..."
    
    # Parse repo URL to get project path
    local project_path
    if [[ "$repo" =~ ^https?://([^/]+)/(.+)$ ]]; then
        project_path="${BASH_REMATCH[2]}"
    elif [[ "$repo" =~ ^([^/]+)/(.+)$ ]]; then
        project_path="$repo"
    else
        return 1
    fi
    
    # Remove .git suffix if present
    project_path="${project_path%.git}"
    
    if glab repo archive "$project_path" --sha "$branch" --format tar.gz -o "$temp_dir/archive.tar.gz" >/dev/null 2>&1; then
        cd "$temp_dir"
        tar -xzf archive.tar.gz --strip-components=1
        return 0
    fi
    
    return 1
}

download_with_ssh() {
    local repo="$1"
    local branch="$2"
    local temp_dir="$3"
    
    info "Downloading using SSH..."
    
    # Convert HTTPS URL to SSH if needed
    local ssh_url="$repo"
    if [[ "$repo" =~ ^https://([^/]+)/(.+)$ ]]; then
        local host="${BASH_REMATCH[1]}"
        local path="${BASH_REMATCH[2]}"
        ssh_url="git@$host:$path"
    fi
    
    # Add .git if not present
    if [[ ! "$ssh_url" =~ \.git$ ]]; then
        ssh_url="$ssh_url.git"
    fi
    
    if git clone --depth 1 --branch "$branch" "$ssh_url" "$temp_dir" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

download_repo() {
    local repo="$1"
    local branch="$2"
    local temp_dir="$3"
    
    # Try glab first if authenticated
    if check_glab_auth; then
        if download_with_glab "$repo" "$branch" "$temp_dir"; then
            return 0
        fi
        warn "glab download failed, trying SSH..."
    fi
    
    # Fallback to SSH
    if download_with_ssh "$repo" "$branch" "$temp_dir"; then
        return 0
    fi
    
    return 1
}

install_rules() {
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    info "Installing from repository: $REPO_URL (branch: $BRANCH)"
    
    if [ "$DRY_RUN" = true ]; then
        info "Would download repository to temporary directory"
        info "Would install rules from configs/.amazonq/rules/ to $TARGET_DIR"
        return 0
    fi
    
    # Download repository
    if ! download_repo "$REPO_URL" "$BRANCH" "$temp_dir"; then
        error "Failed to download repository. Check your authentication and repository access."
        exit 1
    fi
    
    # Check if rules directory exists in repo
    local source_dir="$temp_dir/configs/.amazonq/rules"
    if [ ! -d "$source_dir" ]; then
        error "Repository does not contain configs/.amazonq/rules/ directory"
        exit 1
    fi
    
    # Count rule files
    local rule_count=$(find "$source_dir" -name "*.md" -type f | wc -l)
    if [ "$rule_count" -eq 0 ]; then
        error "No rule files (*.md) found in $source_dir"
        exit 1
    fi
    
    info "Found $rule_count rule file(s) to install"
    
    # Create target directory
    mkdir -p "$TARGET_DIR"
    
    # Remove existing rule files (clean install)
    if [ -d "$TARGET_DIR" ]; then
        find "$TARGET_DIR" -name "*.md" -type f -delete 2>/dev/null || true
    fi
    
    # Install rule files
    local installed_count=0
    while IFS= read -r -d '' rule_file; do
        local filename=$(basename "$rule_file")
        cp "$rule_file" "$TARGET_DIR/"
        success "Installed: $filename"
        ((installed_count++))
    done < <(find "$source_dir" -name "*.md" -type f -print0)
    
    # Create installation marker
    cat > "$INSTALL_MARKER" << EOF
# Boomslang installation marker
installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
repository=$REPO_URL
branch=$BRANCH
version=$SCRIPT_VERSION
rule_count=$installed_count
EOF
    
    success "Successfully installed $installed_count rule file(s) to $TARGET_DIR"
}

uninstall_rules() {
    if [ ! -f "$INSTALL_MARKER" ]; then
        warn "No boomslang installation found (missing $INSTALL_MARKER)"
        if [ "$FORCE" = false ]; then
            echo "Use --force to remove all .md files from $TARGET_DIR anyway"
            exit 1
        fi
    fi
    
    if [ ! -d "$TARGET_DIR" ]; then
        info "Target directory $TARGET_DIR does not exist"
        return 0
    fi
    
    # Count files to be removed
    local rule_count=$(find "$TARGET_DIR" -name "*.md" -type f | wc -l)
    
    if [ "$rule_count" -eq 0 ]; then
        info "No rule files found to remove"
        [ -f "$INSTALL_MARKER" ] && rm -f "$INSTALL_MARKER"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        info "Would remove $rule_count rule file(s) from $TARGET_DIR"
        info "Would remove installation marker: $INSTALL_MARKER"
        return 0
    fi
    
    # Confirm removal unless forced
    if [ "$FORCE" = false ]; then
        echo -e "${YELLOW}This will remove $rule_count rule file(s) from $TARGET_DIR${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Uninstall cancelled"
            exit 0
        fi
    fi
    
    # Remove rule files
    local removed_count=0
    while IFS= read -r -d '' rule_file; do
        local filename=$(basename "$rule_file")
        rm "$rule_file"
        success "Removed: $filename"
        ((removed_count++))
    done < <(find "$TARGET_DIR" -name "*.md" -type f -print0)
    
    # Remove installation marker
    [ -f "$INSTALL_MARKER" ] && rm -f "$INSTALL_MARKER"
    
    # Remove target directory if empty
    if [ -d "$TARGET_DIR" ] && [ -z "$(ls -A "$TARGET_DIR")" ]; then
        rmdir "$TARGET_DIR"
        info "Removed empty directory: $TARGET_DIR"
    fi
    
    success "Successfully removed $removed_count rule file(s)"
}

show_status() {
    if [ -f "$INSTALL_MARKER" ]; then
        info "Boomslang installation found:"
        while IFS= read -r line; do
            if [[ "$line" =~ ^[^#] ]]; then
                echo "  $line"
            fi
        done < "$INSTALL_MARKER"
    else
        info "No boomslang installation found"
    fi
    
    if [ -d "$TARGET_DIR" ]; then
        local rule_count=$(find "$TARGET_DIR" -name "*.md" -type f | wc -l)
        info "Current rule files in $TARGET_DIR: $rule_count"
        if [ "$rule_count" -gt 0 ]; then
            find "$TARGET_DIR" -name "*.md" -type f -exec basename {} \; | sed 's/^/  - /'
        fi
    fi
}

main() {
    log "${BOLD}Amazon Q Developer CLI Standards Installer v$SCRIPT_VERSION${NC}"
    log "================================================================"
    
    check_dependencies
    
    if [ "$UNINSTALL" = true ]; then
        uninstall_rules
        log ""
        success "Uninstall completed successfully!"
        return 0
    fi
    
    # Determine repository URL
    if [ -z "$REPO_URL" ]; then
        if ! REPO_URL=$(detect_repository); then
            error "Could not determine repository URL"
            echo "Please ensure this script is run from a git repository, or"
            echo "have your maintainer configure ORG_REPO_URL in the script, or"
            echo "use --repo to specify the repository manually."
            exit 1
        fi
    fi
    
    # Set default branch if not specified
    if [ -z "$BRANCH" ]; then
        BRANCH="$ORG_BRANCH"
    fi
    
    # Load configuration from repository
    load_config "$REPO_URL" "$BRANCH"
    
    if [ "$DRY_RUN" = true ]; then
        log "${YELLOW}🧪 DRY RUN MODE - No changes will be made${NC}"
        log ""
    fi
    
    show_status
    log ""
    install_rules
    
    log ""
    success "Installation completed successfully!"
    info "Rules are now active in Amazon Q Developer CLI"
}

# Run main function
main "$@"