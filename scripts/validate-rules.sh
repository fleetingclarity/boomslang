#!/bin/bash

# validate-rules.sh - Validate Amazon Q context rules before publishing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RULES_DIR="$PROJECT_ROOT/configs/.amazonq/rules"

echo "🔍 Validating Amazon Q context rules..."

# Check if rules directory exists
if [ ! -d "$RULES_DIR" ]; then
    echo "❌ Error: Rules directory not found at $RULES_DIR"
    exit 1
fi

# Find all markdown files in rules directory
rule_files=$(find "$RULES_DIR" -name "*.md" -type f)

if [ -z "$rule_files" ]; then
    echo "❌ Error: No rule files found in $RULES_DIR"
    exit 1
fi

echo "📁 Found $(echo "$rule_files" | wc -l) rule file(s)"

# Validate each rule file
validation_errors=0

for rule_file in $rule_files; do
    echo "  📄 Validating $(basename "$rule_file")..."
    
    # Check if file is readable
    if [ ! -r "$rule_file" ]; then
        echo "    ❌ Error: Cannot read file"
        ((validation_errors++))
        continue
    fi
    
    # Check if file is not empty
    if [ ! -s "$rule_file" ]; then
        echo "    ❌ Error: File is empty"
        ((validation_errors++))
        continue
    fi
    
    # Check for basic markdown structure
    if ! grep -q "^#" "$rule_file"; then
        echo "    ⚠️  Warning: No markdown headers found"
    fi
    
    # Check for activation protocol keywords
    if grep -qi "activation\|activate\|keyword" "$rule_file"; then
        echo "    ✅ Contains activation protocol"
    else
        echo "    ⚠️  Warning: No activation protocol found"
    fi
    
    # Check for organization customization section
    if grep -qi "maintainer\|organization" "$rule_file"; then
        echo "    ✅ Contains customization section"
    else
        echo "    ⚠️  Warning: No organization customization section found"
    fi
    
    # Check file size (should be reasonable for context rules)
    file_size=$(wc -c < "$rule_file")
    if [ "$file_size" -gt 50000 ]; then
        echo "    ⚠️  Warning: File is quite large (${file_size} bytes) - may exceed context limits"
    fi
    
    echo "    ✅ $(basename "$rule_file") validation complete"
done

# Summary
if [ $validation_errors -eq 0 ]; then
    echo "✅ All rule files passed validation!"
    echo "📦 Ready for publishing"
    exit 0
else
    echo "❌ Found $validation_errors validation error(s)"
    echo "🔧 Please fix errors before publishing"
    exit 1
fi