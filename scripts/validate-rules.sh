#!/bin/bash

# validate-rules.sh - Validate Amazon Q context rules before publishing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROFILES_DIR="$PROJECT_ROOT/configs/.amazonq/profiles"

echo "🔍 Validating Amazon Q context files..."

# Check if profiles directory exists
if [ ! -d "$PROFILES_DIR" ]; then
    echo "❌ Error: Profiles directory not found at $PROFILES_DIR"
    exit 1
fi

# Find all context markdown files in profiles directory
context_files=$(find "$PROFILES_DIR" -name "*-context.md" -type f)

if [ -z "$context_files" ]; then
    echo "❌ Error: No context files found in $PROFILES_DIR"
    exit 1
fi

echo "📁 Found $(echo "$context_files" | wc -l) context file(s)"

# Validate each context file
validation_errors=0

for context_file in $context_files; do
    echo "  📄 Validating $(basename "$context_file")..."
    
    # Check if file is readable
    if [ ! -r "$context_file" ]; then
        echo "    ❌ Error: Cannot read file"
        ((validation_errors++))
        continue
    fi
    
    # Check if file is not empty
    if [ ! -s "$context_file" ]; then
        echo "    ❌ Error: File is empty"
        ((validation_errors++))
        continue
    fi
    
    # Check for basic markdown structure
    if ! grep -q "^#" "$context_file"; then
        echo "    ⚠️  Warning: No markdown headers found"
    fi
    
    # Check for activation protocol keywords
    if grep -qi "activation\|activate\|keyword" "$context_file"; then
        echo "    ✅ Contains activation protocol"
    else
        echo "    ⚠️  Warning: No activation protocol found"
    fi
    
    # Check for organization customization section
    if grep -qi "maintainer\|organization" "$context_file"; then
        echo "    ✅ Contains customization section"
    else
        echo "    ⚠️  Warning: No organization customization section found"
    fi
    
    # Check file size (should be reasonable for context rules)
    file_size=$(wc -c < "$context_file")
    if [ "$file_size" -gt 50000 ]; then
        echo "    ⚠️  Warning: File is quite large (${file_size} bytes) - may exceed context limits"
    fi
    
    echo "    ✅ $(basename "$context_file") validation complete"
done

# Summary
if [ $validation_errors -eq 0 ]; then
    echo "✅ All context files passed validation!"
    echo "📦 Ready for publishing"
    exit 0
else
    echo "❌ Found $validation_errors validation error(s)"
    echo "🔧 Please fix errors before publishing"
    exit 1
fi