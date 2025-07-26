#!/bin/bash

# test-local-install.sh - Test script for local installation workflow
# Tests that example files are skipped and custom profiles are installed correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test configuration
TEST_PROFILE_NAME="test-engineer"
TEST_PROFILE_FILE="configs/.amazonq/profiles/${TEST_PROFILE_NAME}-context.md"
SCRIPT_PATH="./boomslang-install.sh"

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

error() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
}

cleanup() {
    log "Cleaning up test files..."
    rm -f "$TEST_PROFILE_FILE"
    if [ -f ~/.boomslang/.boomslang-installed ]; then
        $SCRIPT_PATH --uninstall --force --quiet >/dev/null 2>&1 || true
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

main() {
    echo -e "${BOLD}Local Installation Test Suite${NC}"
    echo "==============================="
    
    # Check prerequisites
    log "Checking prerequisites..."
    if [ ! -f "$SCRIPT_PATH" ]; then
        error "Installation script not found: $SCRIPT_PATH"
        exit 1
    fi
    
    if [ ! -d "configs/.amazonq/profiles" ]; then
        error "Profiles directory not found: configs/.amazonq/profiles"
        exit 1
    fi
    
    if [ ! -f "configs/.amazonq/profiles/example-engineer-context.md" ]; then
        error "Example file not found: configs/.amazonq/profiles/example-engineer-context.md"
        exit 1
    fi
    
    success "Prerequisites check passed"
    
    # Test 1: Verify dry-run works
    log "Test 1: Verifying dry-run mode..."
    output=$($SCRIPT_PATH --local . --dry-run 2>&1)
    if echo "$output" | grep -q "DRY RUN MODE"; then
        success "Dry-run mode works correctly"
    else
        error "Dry-run mode not working"
        exit 1
    fi
    
    # Test 2: Create test profile from example
    log "Test 2: Creating test profile from example..."
    cp "configs/.amazonq/profiles/example-engineer-context.md" "$TEST_PROFILE_FILE"
    if [ ! -f "$TEST_PROFILE_FILE" ]; then
        error "Failed to create test profile file"
        exit 1
    fi
    success "Test profile created: $TEST_PROFILE_FILE"
    
    # Test 3: Run local installation
    log "Test 3: Running local installation..."
    output=$($SCRIPT_PATH --local . 2>&1)
    
    # Check that example files were skipped
    if echo "$output" | grep -q "Skipped example file"; then
        success "Example files were skipped during installation"
    else
        error "Example files should have been skipped"
        exit 1
    fi
    
    # Check that test profile was installed
    if echo "$output" | grep -q "Copied ${TEST_PROFILE_NAME}-context.md"; then
        success "Test profile was copied"
    else
        error "Test profile should have been copied"
        exit 1
    fi
    
    if echo "$output" | grep -q "Created profile: ${TEST_PROFILE_NAME}"; then
        success "Test profile was created"
    else
        error "Test profile should have been created"
        exit 1
    fi
    
    # Test 4: Verify installation files exist
    log "Test 4: Verifying installation files..."
    if [ -f ~/.boomslang/.boomslang-installed ]; then
        success "Installation marker file exists"
    else
        error "Installation marker file missing"
        exit 1
    fi
    
    if [ -f ~/.boomslang/${TEST_PROFILE_NAME}-context.md ]; then
        success "Context file installed correctly"
    else
        error "Context file not found in ~/.boomslang/"
        exit 1
    fi
    
    if [ -f ~/.aws/amazonq/profiles/${TEST_PROFILE_NAME}/context.json ]; then
        success "Profile directory and context.json created"
    else
        error "Profile context.json not found"
        exit 1
    fi
    
    # Test 5: Verify profile configuration
    log "Test 5: Verifying profile configuration..."
    profile_config=$(cat ~/.aws/amazonq/profiles/${TEST_PROFILE_NAME}/context.json)
    if echo "$profile_config" | grep -q "~/.boomslang/${TEST_PROFILE_NAME}-context.md"; then
        success "Profile references correct context file"
    else
        error "Profile configuration incorrect"
        exit 1
    fi
    
    # Test 6: Test uninstall
    log "Test 6: Testing uninstall..."
    uninstall_output=$($SCRIPT_PATH --uninstall --force 2>&1)
    
    if echo "$uninstall_output" | grep -q "Removed context: ${TEST_PROFILE_NAME}-context.md"; then
        success "Context file was removed"
    else
        error "Context file should have been removed"
        exit 1
    fi
    
    if echo "$uninstall_output" | grep -q "Removed profile: ${TEST_PROFILE_NAME}"; then
        success "Profile was removed"
    else
        error "Profile should have been removed"
        exit 1
    fi
    
    # Test 7: Verify clean uninstall
    log "Test 7: Verifying clean uninstall..."
    if [ ! -f ~/.boomslang/.boomslang-installed ]; then
        success "Installation marker removed"
    else
        error "Installation marker should have been removed"
        exit 1
    fi
    
    if [ ! -f ~/.boomslang/${TEST_PROFILE_NAME}-context.md ]; then
        success "Context file removed from ~/.boomslang/"
    else
        error "Context file should have been removed"
        exit 1
    fi
    
    if [ ! -d ~/.aws/amazonq/profiles/${TEST_PROFILE_NAME} ]; then
        success "Profile directory removed"
    else
        error "Profile directory should have been removed"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}✅ All tests passed!${NC}"
    echo "Local installation workflow is working correctly."
}

# Run main function
main "$@"