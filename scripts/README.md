# Scripts Directory

This directory contains utility scripts for managing Amazon Q Developer CLI standards.

## Files

- `validate-profiles.sh` - Validates context profiles before distribution
- `test-local-install.sh` - Tests local installation workflow
- `../boomslang-install.sh` - Main installation script for end users
- `../install-config.json` - Installation configuration

## Quick Start for Maintainers

### 1. Validate Profiles

Before distributing your customized profiles, validate them:

```bash
./scripts/validate-profiles.sh
```

This checks:
- Profile files exist and are readable
- Files contain activation protocols
- Organization customization sections are present
- File sizes are reasonable

### 2. Test Installation

Test your installation process:

```bash
# Test local installation workflow (recommended)
./test-local-install.sh

# Dry run to see what would happen  
../boomslang-install.sh --dry-run --repo gitlab.yourorg.com/devtools/amazonq-standards

# Test actual installation
../boomslang-install.sh --repo gitlab.yourorg.com/devtools/amazonq-standards --branch develop
```

### 3. Distribute to Team

Share the install script with your team:

```bash
# Direct download and install (zero-config)
curl -sSL https://gitlab.yourorg.com/devtools/amazonq-standards/-/raw/main/boomslang-install.sh | bash

# Or provide the repository for manual installation
git clone https://gitlab.yourorg.com/devtools/amazonq-standards.git
cd amazonq-standards
./boomslang-install.sh
```

## Validation Features

The `validate-profiles.sh` script provides comprehensive checking:

### File Structure Validation
- Ensures `configs/.amazonq/profiles/` directory exists
- Verifies profile files have `.md` extension
- Checks files are readable and non-empty

### Content Validation
- Looks for activation protocol keywords
- Verifies organization customization sections
- Warns about oversized files that might exceed context limits

### Example Output

```bash
🔍 Validating Amazon Q context profiles...
📁 Found 3 profile file(s)
  📄 Validating code-reviewer.md...
    ✅ Contains activation protocol
    ✅ Contains customization section
    ✅ code-reviewer.md validation complete
  📄 Validating security-analyst.md...
    ✅ Contains activation protocol
    ✅ Contains customization section
    ✅ security-analyst.md validation complete
✅ All profile files passed validation!
📦 Ready for distribution
```

## Organization Workflow

### Repository Setup
1. Fork the boomslang repository
2. Customize profiles in `configs/.amazonq/profiles/`
3. Update `install-config.json` with organization details
4. Validate profiles with `./scripts/validate-profiles.sh`

### Distribution Options

#### Option 1: Direct Script Distribution
Users run the install script directly:
```bash
curl -sSL https://gitlab.yourorg.com/devtools/amazonq-standards/-/raw/main/install.sh | bash -s -- --repo gitlab.yourorg.com/devtools/amazonq-standards
```

#### Option 2: Custom Wrapper Script
Create a organization-specific installer:
```bash
#!/bin/bash
# install-acme-standards.sh
REPO="gitlab.acme.com/devtools/amazonq-standards"
curl -sSL "https://$REPO/-/raw/main/install.sh" | bash -s -- --repo "$REPO" "$@"
```

#### Option 3: Documentation
Provide clear instructions for manual installation:
```bash
git clone https://gitlab.yourorg.com/devtools/amazonq-standards.git
cd amazonq-standards
./boomslang-install.sh
```

## Testing and Validation

### Before Distribution
1. Run `./scripts/validate-profiles.sh` to check profile quality
2. Test installation with `./boomslang-install.sh --dry-run`
3. Test uninstallation with `./boomslang-install.sh --uninstall --dry-run`
4. Verify profiles work with Amazon Q Developer CLI

### After Updates
1. Validate profiles after any changes
2. Test installation from different branches
3. Ensure backward compatibility with existing installations

## Security Best Practices

- Keep repository access restricted to authorized maintainers
- Use branch protection rules for main branch
- Review all profile changes before merging
- Regularly audit who has access to the repository
- Consider using signed commits for rule changes

## Troubleshooting

### Common Issues

1. **Profile validation fails**: Check file permissions and content format
2. **Installation fails**: Verify repository access and authentication
3. **Profiles don't activate**: Check activation keywords and syntax

### Getting Help

- Review the installation guide: `docs/installation-guide.md`
- Check Amazon Q Developer CLI documentation
- Validate your JSON configuration files