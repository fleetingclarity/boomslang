#!/bin/bash

# boomslang-install.sh - Install Amazon Q Developer CLI standards
# Pre-configured by organization maintainers for zero-config installation

set -e

# Script configuration - MAINTAINERS: Update these values for your organization
SCRIPT_VERSION="0.2.1"
ORG_REPO_URL="github.com/fleetingclarity/boomslang"  # Set by maintainer for zero-config installation
ORG_BRANCH="main"

# Runtime configuration
CONTEXT_DIR="$HOME/.boomslang"
PROFILES_DIR="$HOME/.aws/amazonq/profiles"
INSTALL_MARKER="$CONTEXT_DIR/.boomslang-installed"

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
CLEAN_BACKUPS=false
FORCE=false
QUIET=false
LOCAL_INSTALL=false

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
    -l, --local PATH        Install from local directory instead of remote repository
    -d, --dry-run          Show what would be done without making changes
    -u, --uninstall        Remove installed standards
    -c, --clean-backups    Remove all backup files
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

    # Install from local directory
    $0 --local /path/to/local/boomslang-repo

    # Uninstall
    $0 --uninstall
    
    # Clean all backups
    $0 --clean-backups

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
        -l|--local)
            REPO_URL="$2"
            LOCAL_INSTALL=true
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
        -c|--clean-backups)
            CLEAN_BACKUPS=true
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
            echo "$detected_repo"
            return 0
        fi
    fi
    
    # If ORG_REPO_URL is set by maintainer, use that
    if [ -n "$ORG_REPO_URL" ]; then
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
    
    # Check for glab or gh (at least one is required)
    if ! command -v glab >/dev/null 2>&1 && ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("glab or gh")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing tools and try again."
        echo "Recommended: Install 'glab' for GitLab or 'gh' for GitHub repositories"
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

check_gh_auth() {
    if command -v gh >/dev/null 2>&1; then
        if gh auth status >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

download_with_glab() {
    local repo="$1"
    local branch="$2"
    local temp_dir="$3"
    
    info "Downloading context files using glab..."
    
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
    
    # Create the directory structure
    mkdir -p "$temp_dir/configs/.amazonq/profiles"
    
    # Download individual context files and install-config.json
    local files_downloaded=0
    
    # Try to download install-config.json
    if glab raw -b "$branch" "$project_path" install-config.json > "$temp_dir/install-config.json" 2>/dev/null; then
        ((files_downloaded++))
        info "Downloaded install-config.json"
    fi
    
    # Dynamically discover and download all non-example context files
    info "Discovering available profiles in repository..."
    
    # Try to list directory contents to find all *-context.md files
    local profile_files=()
    
    # Use glab to list files in the profiles directory
    if command -v glab >/dev/null 2>&1; then
        # Get directory listing from GitLab API
        local dir_contents
        dir_contents=$(glab api "projects/${project_path//\//%2F}/repository/tree?path=configs/.amazonq/profiles&ref=$branch" 2>/dev/null | jq -r '.[] | select(.type=="blob" and (.name | endswith("-context.md")) and (.name | startswith("example-") | not)) | .name' 2>/dev/null || echo "")
        
        if [ -n "$dir_contents" ]; then
            while IFS= read -r filename; do
                if [ -n "$filename" ]; then
                    profile_files+=("$filename")
                fi
            done <<< "$dir_contents"
        fi
    fi
    
    # If we found files via directory listing, download them
    if [ ${#profile_files[@]} -gt 0 ]; then
        info "Found ${#profile_files[@]} profile(s): ${profile_files[*]}"
        for context_file in "${profile_files[@]}"; do
            if glab raw -b "$branch" "$project_path" "configs/.amazonq/profiles/$context_file" > "$temp_dir/configs/.amazonq/profiles/$context_file" 2>/dev/null; then
                ((files_downloaded++))
                info "Downloaded $context_file"
            else
                warn "Failed to download $context_file"
            fi
        done
    else
        # Fallback to common profile names if directory listing failed
        warn "Could not discover profiles, trying common names..."
        local common_profiles=("engineer-context.md" "reviewer-context.md" "architect-context.md" "security-architect-context.md" "senior-engineer-context.md" "tech-lead-context.md")
        for context_file in "${common_profiles[@]}"; do
            if glab raw -b "$branch" "$project_path" "configs/.amazonq/profiles/$context_file" > "$temp_dir/configs/.amazonq/profiles/$context_file" 2>/dev/null; then
                ((files_downloaded++))
                info "Downloaded $context_file"
            fi
        done
    fi
    
    # Return success if we downloaded at least one context file
    if [ "$files_downloaded" -gt 0 ]; then
        return 0
    fi
    
    return 1
}

download_with_gh() {
    local repo="$1"
    local branch="$2"
    local temp_dir="$3"
    
    info "Downloading context files using gh..."
    
    # Parse repo URL to get owner/repo format  
    local repo_path=""
    if [[ "$repo" =~ ^https?://github\.com/(.+)$ ]]; then
        repo_path="${BASH_REMATCH[1]%.git}"
    elif [[ "$repo" =~ ^github\.com/(.+)$ ]]; then
        repo_path="${BASH_REMATCH[1]%.git}"
    elif [[ "$repo" =~ ^([^/]+/[^/]+)$ ]]; then
        repo_path="$repo"
    else
        return 1
    fi
    
    # Create the directory structure
    mkdir -p "$temp_dir/configs/.amazonq/profiles"
    
    # Download individual context files and install-config.json
    local files_downloaded=0
    
    # Try to download install-config.json  
    if gh api "repos/$repo_path/contents/install-config.json?ref=$branch" | jq -r '.content' > "$temp_dir/install-config.b64"; then
        if python3 -c "import base64; print(base64.b64decode(open('$temp_dir/install-config.b64').read()).decode('utf-8'), end='')" > "$temp_dir/install-config.json" 2>/dev/null; then
            rm "$temp_dir/install-config.b64"
            ((files_downloaded++))
            info "Downloaded install-config.json"
        else
            warn "Failed to decode install-config.json"
        fi
    else
        warn "Failed to download install-config.json"
    fi
    
    # Dynamically discover and download all non-example context files
    info "Discovering available profiles in repository..."
    
    # Try to list directory contents to find all *-context.md files
    local profile_files=()
    
    # Get directory listing from GitHub API
    local dir_contents
    dir_contents=$(gh api "repos/$repo_path/contents/configs/.amazonq/profiles?ref=$branch" 2>/dev/null | jq -r '.[] | select(.type=="file" and (.name | endswith("-context.md")) and (.name | startswith("example-") | not)) | .name' 2>/dev/null || echo "")
    
    if [ -n "$dir_contents" ]; then
        while IFS= read -r filename; do
            if [ -n "$filename" ]; then
                profile_files+=("$filename")
            fi
        done <<< "$dir_contents"
    fi
    
    # If we found files via directory listing, download them
    if [ ${#profile_files[@]} -gt 0 ]; then
        info "Found ${#profile_files[@]} profile(s): ${profile_files[*]}"
        for context_file in "${profile_files[@]}"; do
            if gh api "repos/$repo_path/contents/configs/.amazonq/profiles/$context_file?ref=$branch" | jq -r '.content' > "$temp_dir/$context_file.b64" 2>/dev/null; then  
                if python3 -c "import base64; print(base64.b64decode(open('$temp_dir/$context_file.b64').read()).decode('utf-8'), end='')" > "$temp_dir/configs/.amazonq/profiles/$context_file" 2>/dev/null; then
                    rm "$temp_dir/$context_file.b64"
                    # Check if file is not empty
                    if [ -s "$temp_dir/configs/.amazonq/profiles/$context_file" ]; then
                        ((files_downloaded++))
                        info "Downloaded $context_file"
                    else
                        rm -f "$temp_dir/configs/.amazonq/profiles/$context_file"
                        warn "Downloaded empty $context_file"
                    fi
                else
                    warn "Failed to decode $context_file"
                fi
            else
                warn "Failed to download $context_file"
            fi
        done
    else
        # Fallback to common profile names if directory listing failed
        warn "Could not discover profiles, trying common names..."
        local common_profiles=("engineer-context.md" "reviewer-context.md" "architect-context.md" "security-architect-context.md" "senior-engineer-context.md" "tech-lead-context.md")
        for context_file in "${common_profiles[@]}"; do
            if gh api "repos/$repo_path/contents/configs/.amazonq/profiles/$context_file?ref=$branch" | jq -r '.content' > "$temp_dir/$context_file.b64" 2>/dev/null; then  
                if python3 -c "import base64; print(base64.b64decode(open('$temp_dir/$context_file.b64').read()).decode('utf-8'), end='')" > "$temp_dir/configs/.amazonq/profiles/$context_file" 2>/dev/null; then
                    rm "$temp_dir/$context_file.b64"
                    # Check if file is not empty
                    if [ -s "$temp_dir/configs/.amazonq/profiles/$context_file" ]; then
                        ((files_downloaded++))
                        info "Downloaded $context_file"
                    else
                        rm -f "$temp_dir/configs/.amazonq/profiles/$context_file"
                        warn "Downloaded empty $context_file"
                    fi
                else
                    warn "Failed to decode $context_file"
                fi
            fi
        done
    fi
    
    # Return success if we downloaded at least one context file
    if [ "$files_downloaded" -gt 0 ]; then
        return 0
    fi
    
    return 1
}

install_from_local() {
    local source_dir="$1"
    local temp_dir="$2"
    
    info "Installing from local directory: $source_dir"
    
    # Validate local directory structure
    if [ ! -d "$source_dir" ]; then
        error "Local directory does not exist: $source_dir"
        return 1
    fi
    
    local profiles_source="$source_dir/configs/.amazonq/profiles"
    if [ ! -d "$profiles_source" ]; then
        error "Local directory missing required structure: configs/.amazonq/profiles/"
        return 1
    fi
    
    # Create temp directory structure and copy files
    mkdir -p "$temp_dir/configs/.amazonq/profiles"
    
    # Copy context files (skip example files)
    local files_copied=0
    for context_file in "$profiles_source"/*-context.md; do
        if [ -f "$context_file" ]; then
            local filename=$(basename "$context_file")
            # Skip example files
            if [[ "$filename" =~ ^example- ]]; then
                info "Skipped example file: $filename"
                continue
            fi
            cp "$context_file" "$temp_dir/configs/.amazonq/profiles/"
            info "Copied $filename"
            ((files_copied++))
        fi
    done
    
    # Copy install-config.json if it exists
    if [ -f "$source_dir/install-config.json" ]; then
        cp "$source_dir/install-config.json" "$temp_dir/"
        info "Copied install-config.json"
        ((files_copied++))
    fi
    
    if [ "$files_copied" -eq 0 ]; then
        error "No context files (*-context.md) found in $profiles_source"
        return 1
    fi
    
    return 0
}

download_repo() {
    local repo="$1"
    local branch="$2"
    local temp_dir="$3"
    
    # Try glab first if authenticated (works for GitLab repos)
    if check_glab_auth; then
        if download_with_glab "$repo" "$branch" "$temp_dir"; then
            return 0
        fi
        warn "glab download failed, trying gh..."
    fi
    
    # Try gh if authenticated (works for GitHub repos)
    if check_gh_auth; then
        if download_with_gh "$repo" "$branch" "$temp_dir"; then
            return 0
        fi
        warn "gh download failed..."
    fi
    
    # If we get here, both methods failed
    error "Failed to download repository files"
    echo "Please ensure you are authenticated with either:"
    echo "  - 'glab auth login' for GitLab repositories"
    echo "  - 'gh auth login' for GitHub repositories"
    echo "And that you have access to the repository: $repo"
    
    return 1
}

install_rules() {
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    if [ "$LOCAL_INSTALL" = true ]; then
        info "Installing from local directory: $REPO_URL"
    else
        info "Installing from repository: $REPO_URL (branch: $BRANCH)"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        if [ "$LOCAL_INSTALL" = true ]; then
            info "Would copy files from local directory to temporary directory"
        else
            info "Would download repository to temporary directory"
        fi
        info "Would install context files from configs/.amazonq/profiles/ to $CONTEXT_DIR"
        info "Would create profiles in $PROFILES_DIR"
        return 0
    fi
    
    # Get files (either download or copy from local)
    if [ "$LOCAL_INSTALL" = true ]; then
        if ! install_from_local "$REPO_URL" "$temp_dir"; then
            error "Failed to copy from local directory."
            exit 1
        fi
    else
        if ! download_repo "$REPO_URL" "$BRANCH" "$temp_dir"; then
            error "Failed to download repository. Check your authentication and repository access."
            exit 1
        fi
    fi
    
    # Check if profiles directory exists in repo
    local source_dir="$temp_dir/configs/.amazonq/profiles"
    if [ ! -d "$source_dir" ]; then
        error "Repository does not contain configs/.amazonq/profiles/ directory"
        exit 1
    fi
    
    # Count context files
    local context_count=$(find "$source_dir" -name "*-context.md" -type f | wc -l)
    if [ "$context_count" -eq 0 ]; then
        error "No context files (*-context.md) found in $source_dir"
        exit 1
    fi
    
    info "Found $context_count context file(s) to install"
    
    # Create directories
    mkdir -p "$CONTEXT_DIR"
    mkdir -p "$PROFILES_DIR"
    
    # Remove existing context files (clean install)
    if [ -d "$CONTEXT_DIR" ]; then
        find "$CONTEXT_DIR" -name "*-context.md" -type f -delete 2>/dev/null || true
    fi
    
    # Install context files and create profiles
    local installed_count=0
    local profiles_created=0
    
    while IFS= read -r -d '' rule_file; do
        local filename=$(basename "$rule_file")
        local context_path="$CONTEXT_DIR/$filename"
        
        # Copy context file
        cp "$rule_file" "$context_path"
        success "Installed context: $filename"
        ((installed_count++))
        
        # Extract profile name from filename (remove -context.md suffix)
        if [[ "$filename" =~ ^(.+)-context\.md$ ]]; then
            local profile_name="${BASH_REMATCH[1]}"
            local profile_dir="$PROFILES_DIR/$profile_name"
            
            # Create profile directory
            mkdir -p "$profile_dir"
            
            # Create profile context.json with tilde notation for portability
            cat > "$profile_dir/context.json" << EOF
{
  "paths": [
    "~/.boomslang/$filename"
  ],
  "hooks": {}
}
EOF
            success "Created profile: $profile_name"
            ((profiles_created++))
        fi
    done < <(find "$source_dir" -name "*-context.md" -type f -print0)
    
    # Create installation marker
    cat > "$INSTALL_MARKER" << EOF
# Boomslang installation marker
installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
repository=$REPO_URL
branch=$BRANCH
version=$SCRIPT_VERSION
context_files=$installed_count
profiles_created=$profiles_created
EOF
    
    success "Successfully installed $installed_count context file(s) to $CONTEXT_DIR"
    success "Successfully created $profiles_created profile(s) in $PROFILES_DIR"
}

uninstall_rules() {
    if [ ! -f "$INSTALL_MARKER" ]; then
        warn "No boomslang installation found (missing $INSTALL_MARKER)"
        if [ "$FORCE" = false ]; then
            echo "Use --force to remove boomslang files anyway"
            exit 1
        fi
    fi
    
    # Count context files and profiles to be removed
    local context_count=0
    local profile_count=0
    
    if [ -d "$CONTEXT_DIR" ]; then
        context_count=$(find "$CONTEXT_DIR" -name "*-context.md" -type f | wc -l)
    fi
    
    # Count boomslang-created profiles
    if [ -d "$PROFILES_DIR" ]; then
        for profile_dir in "$PROFILES_DIR"/*; do
            if [ -d "$profile_dir" ] && [ -f "$profile_dir/context.json" ]; then
                # Check if profile references ~/.boomslang/
                if grep -q "\.boomslang/" "$profile_dir/context.json" 2>/dev/null; then
                    ((profile_count++))
                fi
            fi
        done
    fi
    
    if [ "$context_count" -eq 0 ] && [ "$profile_count" -eq 0 ]; then
        info "No boomslang files found to remove"
        [ -f "$INSTALL_MARKER" ] && rm -f "$INSTALL_MARKER"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        info "Would remove $context_count context file(s) from $CONTEXT_DIR"
        info "Would remove $profile_count profile(s) from $PROFILES_DIR"
        info "Would remove installation marker: $INSTALL_MARKER"
        return 0
    fi
    
    # Confirm removal unless forced
    if [ "$FORCE" = false ]; then
        echo -e "${YELLOW}This will remove:${NC}"
        echo "  - $context_count context file(s) from $CONTEXT_DIR"
        echo "  - $profile_count profile(s) from $PROFILES_DIR"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Uninstall cancelled"
            exit 0
        fi
    fi
    
    # Remove context files
    local removed_context=0
    if [ -d "$CONTEXT_DIR" ]; then
        while IFS= read -r -d '' context_file; do
            local filename=$(basename "$context_file")
            rm "$context_file"
            success "Removed context: $filename"
            ((removed_context++))
        done < <(find "$CONTEXT_DIR" -name "*-context.md" -type f -print0)
    fi
    
    # Remove profiles that reference ~/.boomslang/
    local removed_profiles=0
    if [ -d "$PROFILES_DIR" ]; then
        for profile_dir in "$PROFILES_DIR"/*; do
            if [ -d "$profile_dir" ] && [ -f "$profile_dir/context.json" ]; then
                if grep -q "\.boomslang/" "$profile_dir/context.json" 2>/dev/null; then
                    local profile_name=$(basename "$profile_dir")
                    rm -rf "$profile_dir"
                    success "Removed profile: $profile_name"
                    ((removed_profiles++))
                fi
            fi
        done
    fi
    
    # Remove installation marker
    [ -f "$INSTALL_MARKER" ] && rm -f "$INSTALL_MARKER"
    
    # Remove context directory if empty
    if [ -d "$CONTEXT_DIR" ] && [ -z "$(ls -A "$CONTEXT_DIR")" ]; then
        rmdir "$CONTEXT_DIR"
        info "Removed empty directory: $CONTEXT_DIR"
    fi
    
    success "Successfully removed $removed_context context file(s) and $removed_profiles profile(s)"
}

clean_backups() {
    local backups_dir="$CONTEXT_DIR/backups"
    
    if [ ! -d "$backups_dir" ]; then
        info "No backup directory found at $backups_dir"
        return 0
    fi
    
    # Count backup directories
    local backup_count=0
    if [ -d "$backups_dir" ]; then
        backup_count=$(find "$backups_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
    fi
    
    if [ "$backup_count" -eq 0 ]; then
        info "No backups found to remove"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        info "Would remove $backup_count backup(s) from $backups_dir"
        find "$backups_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/  - /'
        return 0
    fi
    
    # Confirm removal unless forced
    if [ "$FORCE" = false ]; then
        echo -e "${YELLOW}This will remove $backup_count backup(s) from:${NC}"
        echo "  $backups_dir"
        echo
        find "$backups_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/  - /'
        echo
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Clean backups cancelled"
            exit 0
        fi
    fi
    
    # Remove all backup directories
    local removed_count=0
    while IFS= read -r -d '' backup_dir; do
        local backup_name=$(basename "$backup_dir")
        rm -rf "$backup_dir"
        success "Removed backup: $backup_name"
        ((removed_count++))
    done < <(find "$backups_dir" -mindepth 1 -maxdepth 1 -type d -print0)
    
    # Remove backups directory if empty
    if [ -d "$backups_dir" ] && [ -z "$(ls -A "$backups_dir")" ]; then
        rmdir "$backups_dir"
        info "Removed empty backups directory"
    fi
    
    success "Successfully removed $removed_count backup(s)"
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
    
    # Show context files
    if [ -d "$CONTEXT_DIR" ]; then
        local context_count=$(find "$CONTEXT_DIR" -name "*-context.md" -type f | wc -l)
        info "Context files in $CONTEXT_DIR: $context_count"
        if [ "$context_count" -gt 0 ]; then
            find "$CONTEXT_DIR" -name "*-context.md" -type f -exec basename {} \; | sed 's/^/  - /'
        fi
    fi
    
    # Show profiles
    if [ -d "$PROFILES_DIR" ]; then
        local profile_count=0
        info "Boomslang profiles in $PROFILES_DIR:"
        for profile_dir in "$PROFILES_DIR"/*; do
            if [ -d "$profile_dir" ] && [ -f "$profile_dir/context.json" ]; then
                if grep -q "\.boomslang/" "$profile_dir/context.json" 2>/dev/null; then
                    local profile_name=$(basename "$profile_dir")
                    echo "  - $profile_name"
                    ((profile_count++))
                fi
            fi
        done
        if [ "$profile_count" -eq 0 ]; then
            echo "  (none found)"
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
    
    if [ "$CLEAN_BACKUPS" = true ]; then
        clean_backups
        log ""
        success "Clean backups completed successfully!"
        return 0
    fi
    
    # Determine repository URL (skip for local install)
    if [ "$LOCAL_INSTALL" = false ] && [ -z "$REPO_URL" ]; then
        if ! REPO_URL=$(detect_repository); then
            error "Could not determine repository URL"
            echo "Please ensure this script is run from a git repository, or"
            echo "have your maintainer configure ORG_REPO_URL in the script, or"
            echo "use --repo to specify the repository manually."
            exit 1
        fi
        info "Auto-detected repository: $REPO_URL"
    fi
    
    # Set default branch if not specified
    if [ -z "$BRANCH" ]; then
        BRANCH="$ORG_BRANCH"
    fi
    
    # Try to load configuration from repository (optional, skip for local)
    if [ "$LOCAL_INSTALL" = false ]; then
        if ! load_config "$REPO_URL" "$BRANCH"; then
            warn "Could not load remote configuration, using defaults"
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "${YELLOW}🧪 DRY RUN MODE - No changes will be made${NC}"
        log ""
    fi
    
    show_status
    log ""
    install_rules
    
    log ""
    success "Installation completed successfully!"
    info "Profiles are now available in Amazon Q Developer CLI"
    info "Use 'q chat' then '/profile set <profile-name>' to switch profiles"
}

# Run main function
main "$@"