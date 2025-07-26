#!/bin/bash

# release.sh - Release script for boomslang repository
# This script is for maintainers to create boomslang releases, not for end users

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_SCRIPT="$PROJECT_ROOT/boomslang-install.sh"

log() {
    echo -e "${BLUE}[RELEASE]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

usage() {
    cat << EOF
${BOLD}Boomslang Release Script${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS] [version]

${BOLD}ARGUMENTS:${NC}
    version     New version number (e.g., 1.0.0, 1.2.3-beta)
                If not provided, will auto-suggest based on conventional commits

${BOLD}OPTIONS:${NC}
    --suggest          Show suggested version and exit (no release)
    --dry-run          Show what would be done without making changes
    --skip-tests       Skip running validation tests
    --no-git           Don't create git tag or push changes
    --no-github        Don't create GitHub release
    -h, --help         Show this help message

${BOLD}EXAMPLES:${NC}
    # Auto-suggest version based on conventional commits
    $0 --suggest
    
    # Create release with auto-suggested version
    $0
    
    # Create specific release version
    $0 1.0.0
    
    # Dry run with auto-suggested version
    $0 --dry-run
    
    # Pre-release version
    $0 0.9.0-beta

${BOLD}CONVENTIONAL COMMITS:${NC}
    The script analyzes commit messages since the last release tag:
    - feat: triggers minor version bump
    - fix: triggers patch version bump
    - BREAKING CHANGE: triggers major version bump
    - docs/chore/refactor: triggers patch version bump

${BOLD}PREREQUISITES:${NC}
    - Clean git working directory
    - gh CLI installed and authenticated (for GitHub releases)
    - Main branch checked out
EOF
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        error "Cannot find boomslang-install.sh. Are you in the right directory?"
        exit 1
    fi
    
    # Check if git working directory is clean
    if [ "$NO_GIT" = false ] && ! git diff-index --quiet HEAD --; then
        error "Git working directory is not clean. Please commit or stash changes."
        exit 1
    fi
    
    # Check if we're on main branch
    if [ "$NO_GIT" = false ]; then
        current_branch=$(git branch --show-current)
        if [ "$current_branch" != "main" ]; then
            error "Not on main branch (currently on '$current_branch'). Please switch to main."
            exit 1
        fi
    fi
    
    # Check if gh CLI is available for GitHub releases
    if [ "$NO_GITHUB" = false ] && ! command -v gh >/dev/null 2>&1; then
        warn "gh CLI not found. GitHub release will be skipped."
        NO_GITHUB=true
    fi
    
    # Check if gh is authenticated
    if [ "$NO_GITHUB" = false ] && ! gh auth status >/dev/null 2>&1; then
        warn "gh CLI not authenticated. GitHub release will be skipped."
        NO_GITHUB=true
    fi
    
    success "Prerequisites check passed"
}

get_current_version() {
    if [ -f "$INSTALL_SCRIPT" ]; then
        grep '^SCRIPT_VERSION=' "$INSTALL_SCRIPT" | cut -d'"' -f2
    else
        echo "unknown"
    fi
}

get_last_release_tag() {
    # Get the latest release tag (v*.*.*)
    git tag -l --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo ""
}

parse_conventional_commits() {
    local since_ref="$1"
    local temp_file=$(mktemp)
    
    # Get commits since last release (or all commits if no previous release)
    if [ -n "$since_ref" ]; then
        git log --pretty=format:"%s" "${since_ref}..HEAD" > "$temp_file"
    else
        git log --pretty=format:"%s" > "$temp_file"
    fi
    
    # Parse conventional commits
    local has_breaking=false
    local has_feat=false
    local has_fix=false
    
    # Check for breaking changes
    if grep -q "BREAKING CHANGE" "$temp_file" || grep -q "!:" "$temp_file"; then
        has_breaking=true
    fi
    
    # Check for features
    if grep -q "^feat" "$temp_file"; then
        has_feat=true
    fi
    
    # Check for fixes
    if grep -q "^fix" "$temp_file"; then
        has_fix=true
    fi
    
    rm "$temp_file"
    
    # Return bump type
    if [ "$has_breaking" = true ]; then
        echo "major"
    elif [ "$has_feat" = true ]; then
        echo "minor"
    elif [ "$has_fix" = true ]; then
        echo "patch"
    else
        echo "patch"  # Default to patch for other changes
    fi
}

suggest_version() {
    local current_version="$1"
    local last_tag
    last_tag=$(get_last_release_tag)
    
    # If no previous tags, use current version as base and apply conventional commit bumps
    if [ -z "$last_tag" ]; then
        # Parse current version and apply bump based on conventional commits
        local version_clean="${current_version#v}"
        local major minor patch
        IFS='.' read -r major minor patch <<< "$version_clean"
        
        # Handle pre-release versions
        if [[ "$patch" == *"-"* ]]; then
            patch="${patch%%-*}"
        fi
        
        # Get suggested bump type from all commits (since no previous tags)
        local bump_type
        bump_type=$(parse_conventional_commits "")
        
        # Calculate new version from current
        case "$bump_type" in
            major)
                echo "$((major + 1)).0.0"
                ;;
            minor)
                echo "${major}.$((minor + 1)).0"
                ;;
            patch)
                echo "${major}.${minor}.$((patch + 1))"
                ;;
        esac
        return
    fi
    
    # Parse current version
    local version_clean="${current_version#v}"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version_clean"
    
    # Handle pre-release versions
    if [[ "$patch" == *"-"* ]]; then
        patch="${patch%%-*}"
    fi
    
    # Get suggested bump type from conventional commits
    local bump_type
    bump_type=$(parse_conventional_commits "$last_tag")
    
    # Calculate new version
    case "$bump_type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "${major}.$((minor + 1)).0"
            ;;
        patch)
            echo "${major}.${minor}.$((patch + 1))"
            ;;
    esac
}

generate_changelog_content() {
    local version="$1"
    local since_ref="$2"
    local temp_file=$(mktemp)
    local changelog_content=""
    
    # Get commits since last release
    if [ -n "$since_ref" ]; then
        git log --pretty=format:"%s|%H|%an" "${since_ref}..HEAD" > "$temp_file"
    else
        git log --pretty=format:"%s|%H|%an" > "$temp_file"
    fi
    
    # Parse commits by type
    local features=()
    local fixes=()
    local docs=()
    local breaking=()
    local other=()
    
    while IFS='|' read -r subject hash author; do
        if [[ "$subject" =~ ^feat(\(.+\))?!?: ]]; then
            if [[ "$subject" =~ ! ]] || grep -q "BREAKING CHANGE" <<< "$(git show --format=%B -s "$hash")"; then
                breaking+=("$subject")
            else
                features+=("$subject")
            fi
        elif [[ "$subject" =~ ^fix(\(.+\))?: ]]; then
            fixes+=("$subject")
        elif [[ "$subject" =~ ^docs(\(.+\))?: ]]; then
            docs+=("$subject")
        elif [[ "$subject" =~ ^(chore|refactor|test|style|perf|ci|build)(\(.+\))?: ]]; then
            other+=("$subject")
        else
            other+=("$subject")
        fi
    done < "$temp_file"
    
    # Build changelog content
    if [ ${#breaking[@]} -gt 0 ]; then
        changelog_content+="### ⚠ BREAKING CHANGES\n\n"
        for item in "${breaking[@]}"; do
            changelog_content+="- ${item}\n"
        done
        changelog_content+="\n"
    fi
    
    if [ ${#features[@]} -gt 0 ]; then
        changelog_content+="### ✨ Features\n\n"
        for item in "${features[@]}"; do
            changelog_content+="- ${item}\n"
        done
        changelog_content+="\n"
    fi
    
    if [ ${#fixes[@]} -gt 0 ]; then
        changelog_content+="### 🐛 Bug Fixes\n\n"
        for item in "${fixes[@]}"; do
            changelog_content+="- ${item}\n"
        done
        changelog_content+="\n"
    fi
    
    if [ ${#docs[@]} -gt 0 ]; then
        changelog_content+="### 📚 Documentation\n\n"
        for item in "${docs[@]}"; do
            changelog_content+="- ${item}\n"
        done
        changelog_content+="\n"
    fi
    
    if [ ${#other[@]} -gt 0 ]; then
        changelog_content+="### 🔧 Other Changes\n\n"
        for item in "${other[@]}"; do
            changelog_content+="- ${item}\n"
        done
        changelog_content+="\n"
    fi
    
    rm "$temp_file"
    echo -e "$changelog_content"
}

validate_version() {
    local version="$1"
    
    # Basic semver validation
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
        error "Invalid version format. Expected semver (e.g., 1.0.0, 1.2.3-beta)"
        exit 1
    fi
    
    # Check if version already exists as a git tag
    if [ "$NO_GIT" = false ] && git tag -l | grep -q "^v$version$"; then
        error "Version v$version already exists as a git tag"
        exit 1
    fi
}

run_tests() {
    if [ "$SKIP_TESTS" = true ]; then
        warn "Skipping tests as requested"
        return 0
    fi
    
    log "Running validation tests..."
    
    # Run profile validation
    if ! "$SCRIPT_DIR/validate-profiles.sh"; then
        error "Profile validation failed"
        exit 1
    fi
    
    # Run local install test
    if ! "$SCRIPT_DIR/test-local-install.sh"; then
        error "Local installation test failed"
        exit 1
    fi
    
    success "All tests passed"
}

update_version() {
    local new_version="$1"
    local current_version
    current_version=$(get_current_version)
    
    log "Updating version from $current_version to $new_version"
    
    if [ "$DRY_RUN" = true ]; then
        log "Would update SCRIPT_VERSION in $INSTALL_SCRIPT"
        return 0
    fi
    
    # Update version in install script
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^SCRIPT_VERSION=.*/SCRIPT_VERSION=\"$new_version\"/" "$INSTALL_SCRIPT"
    else
        # Linux
        sed -i "s/^SCRIPT_VERSION=.*/SCRIPT_VERSION=\"$new_version\"/" "$INSTALL_SCRIPT"
    fi
    
    success "Version updated in install script"
}


create_git_tag() {
    local version="$1"
    
    if [ "$NO_GIT" = true ]; then
        warn "Skipping git operations as requested"
        return 0
    fi
    
    log "Creating git tag and pushing changes..."
    
    if [ "$DRY_RUN" = true ]; then
        log "Would commit changes and create tag v$version"
        return 0
    fi
    
    # Commit version changes
    git add "$INSTALL_SCRIPT"
    git commit -m "chore: release version $version

- Update version to $version in boomslang-install.sh"
    
    # Create annotated tag
    git tag -a "v$version" -m "Release version $version"
    
    # Push changes and tag
    git push origin main
    git push origin "v$version"
    
    success "Git tag v$version created and pushed"
}

create_github_release() {
    local version="$1"
    local previous_tag="$2"
    
    if [ "$NO_GITHUB" = true ]; then
        warn "Skipping GitHub release as requested"
        return 0
    fi
    
    log "Creating GitHub release with auto-generated notes..."
    
    if [ "$DRY_RUN" = true ]; then
        log "Would create GitHub release for v$version with generated changelog"
        log "Release notes would be:"
        generate_changelog_content "$version" "$previous_tag" | sed 's/^/  /'
        return 0
    fi
    
    # Generate release notes from conventional commits using the previous tag
    local release_notes
    release_notes=$(generate_changelog_content "$version" "$previous_tag")
    
    if [ -z "$release_notes" ]; then
        release_notes="Release version $version

No significant changes found since the last release."
    fi
    
    # Create GitHub release
    gh release create "v$version" \
        --title "Release v$version" \
        --notes "$release_notes" \
        --latest
    
    success "GitHub release created: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/v$version"
}

main() {
    local version=""
    local DRY_RUN=false
    local SKIP_TESTS=false
    local NO_GIT=false
    local NO_GITHUB=false
    local SUGGEST_ONLY=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --suggest)
                SUGGEST_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --no-git)
                NO_GIT=true
                shift
                ;;
            --no-github)
                NO_GITHUB=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [ -z "$version" ]; then
                    version="$1"
                else
                    error "Too many arguments"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    echo -e "${BOLD}Boomslang Release Script${NC}"
    echo "========================="
    
    local current_version
    current_version=$(get_current_version)
    local last_tag
    last_tag=$(get_last_release_tag)
    
    log "Current version: $current_version"
    if [ -n "$last_tag" ]; then
        log "Last release tag: $last_tag"
    else
        log "No previous release tags found"
    fi
    
    # Auto-suggest version if not provided
    if [ -z "$version" ]; then
        version=$(suggest_version "$current_version")
        local bump_type
        bump_type=$(parse_conventional_commits "$last_tag")
        
        log "Auto-suggested version: $version (based on ${bump_type} changes)"
        
        if [ "$SUGGEST_ONLY" = true ]; then
            echo ""
            log "Suggested version based on conventional commits:"
            echo "  Current: $current_version"
            echo "  Suggested: $version"
            echo "  Bump type: $bump_type"
            echo ""
            log "Changes since ${last_tag:-'beginning'}:"
            generate_changelog_content "$version" "$last_tag" | sed 's/^/  /'
            exit 0
        fi
    fi
    
    log "Target version: $version"
    
    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN MODE - No changes will be made"
    fi
    
    # Validation
    validate_version "$version"
    check_prerequisites
    
    # Release process
    run_tests
    update_version "$version"
    create_git_tag "$version"
    create_github_release "$version" "$last_tag"
    
    echo ""
    success "Release $version completed successfully!"
    
    if [ "$DRY_RUN" = false ]; then
        echo ""
        log "Next steps:"
        echo "  1. Verify the release at: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'your-org/boomslang')/releases"
        echo "  2. Update any dependent documentation"
        echo "  3. Announce the release to your team"
    fi
}

# Run main function
main "$@"