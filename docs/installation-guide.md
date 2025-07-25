# Installation Guide

This guide explains how to install and manage Amazon Q Developer CLI standards using the simple install script.

## Quick Start

### For End Users

```bash
# Zero-config installation (recommended)
curl -sSL https://gitlab.yourorg.com/devtools/amazonq-standards/-/raw/main/boomslang-install.sh | bash

# Or download and run manually
curl -O https://gitlab.yourorg.com/devtools/amazonq-standards/-/raw/main/boomslang-install.sh
chmod +x boomslang-install.sh
./boomslang-install.sh
```

### For Organization Maintainers

1. Fork this repository
2. Configure `ORG_REPO_URL` in `boomslang-install.sh` with your repository URL
3. Customize the context files in `configs/.amazonq/profiles/`
4. Update `install-config.json` with your organization details
5. Distribute the pre-configured install script to your team

## Authentication Setup

The installer supports two authentication methods for private GitLab repositories:

### Option 1: GitLab CLI (Recommended)

```bash
# Install glab
brew install glab

# Authenticate with your GitLab instance
glab auth login --hostname gitlab.yourorg.com

# Verify authentication
glab auth status
```

### Option 2: SSH Keys

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your.email@yourorg.com"

# Add to ssh-agent
ssh-add ~/.ssh/id_ed25519

# Add public key to GitLab (copy and paste into GitLab → Settings → SSH Keys)
cat ~/.ssh/id_ed25519.pub
```

## Usage Examples

### Basic Installation

```bash
# Install from default repository
./boomslang-install.sh

# Install from custom repository
./boomslang-install.sh --repo gitlab.acme.com/devtools/amazonq-standards

# Install from specific branch
./boomslang-install.sh --repo gitlab.acme.com/devtools/amazonq-standards --branch develop
```

### Dry Run Mode

```bash
# See what would be installed without making changes
./boomslang-install.sh --dry-run

# Dry run with custom repository
./boomslang-install.sh --dry-run --repo gitlab.acme.com/devtools/amazonq-standards
```

### Uninstallation

```bash
# Uninstall with confirmation prompt
./boomslang-install.sh --uninstall

# Force uninstall without prompts
./boomslang-install.sh --uninstall --force

# Dry run uninstall to see what would be removed
./boomslang-install.sh --uninstall --dry-run
```

### Backup Management

```bash
# Remove all backup files with confirmation
./boomslang-install.sh --clean-backups

# Force remove all backups without prompts
./boomslang-install.sh --clean-backups --force

# Dry run to see what backups would be removed
./boomslang-install.sh --clean-backups --dry-run
```

### Quiet Mode

```bash
# Install with minimal output (errors only)
./boomslang-install.sh --quiet --repo gitlab.acme.com/devtools/amazonq-standards
```

## Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `-r, --repo URL` | GitLab repository URL | `--repo gitlab.acme.com/devtools/amazonq-standards` |
| `-b, --branch BRANCH` | Git branch to install from | `--branch develop` |
| `-d, --dry-run` | Show what would be done without making changes | `--dry-run` |
| `-u, --uninstall` | Remove installed standards | `--uninstall` |
| `-c, --clean-backups` | Remove all backup files | `--clean-backups` |
| `-f, --force` | Force operation without prompts | `--force` |
| `-q, --quiet` | Suppress non-error output | `--quiet` |
| `-h, --help` | Show help message | `--help` |
| `-v, --version` | Show version information | `--version` |

## What Gets Installed

The installer:

1. **Downloads repository** using `glab` or SSH
2. **Installs context files** from `configs/.amazonq/profiles/*.md` to `~/.boomslang/`
3. **Creates profiles** in `~/.aws/amazonq/profiles/<profile-name>/context.json`
4. **Creates installation marker** at `~/.boomslang/.boomslang-installed`

### Installation Marker

The installation marker contains metadata about the installation:

```
# Boomslang installation marker
installed_at=2024-01-15T10:30:00Z
repository=gitlab.acme.com/devtools/amazonq-standards
branch=main
version=0.1.0
context_files=3
profiles_created=3
```

## Directory Structure

```
~/.boomslang/                       # Centralized context files
├── engineer-context.md            # Engineering context
├── reviewer-context.md            # Code review context
├── architect-context.md           # Architecture context
└── .boomslang-installed           # Installation marker

~/.aws/amazonq/profiles/           # Amazon Q profiles
├── engineer/
│   └── context.json               # Points to ~/.boomslang/engineer-context.md
├── reviewer/
│   └── context.json               # Points to ~/.boomslang/reviewer-context.md
└── architect/
    └── context.json               # Points to ~/.boomslang/architect-context.md
```

## Using Profiles

After installation, you can use the profiles in Amazon Q Developer CLI:

### Switching Profiles

```bash
# Start Amazon Q chat
q chat

# List available profiles
/profile

# Switch to engineer profile for development tasks
/profile set engineer

# Switch to reviewer profile for code reviews
/profile set reviewer

# Switch to architect profile for system design
/profile set architect

# Return to default profile
/profile set default
```

### Profile-Specific Behavior

Each profile provides specialized context:

- **Engineer**: Focused on code implementation, debugging, and best practices
- **Reviewer**: Optimized for code review, security analysis, and quality assessment  
- **Architect**: Designed for system design, scalability, and technical strategy

The profiles use keyword activation, so they'll automatically adjust their behavior based on your requests.

## Troubleshooting

### Authentication Issues

**Problem**: `Failed to download repository. Check your authentication and repository access.`

**Solutions**:
1. **For glab**: Run `glab auth login` and follow the prompts
2. **For SSH**: Ensure your SSH key is added to GitLab and ssh-agent
3. **Test access**: Try `glab repo view REPO` or `git clone git@gitlab.yourorg.com:org/repo.git`

### Permission Issues

**Problem**: `Permission denied` when accessing GitLab

**Solutions**:
1. Verify you have access to the repository in GitLab web interface
2. Check if repository is private and you're a member
3. Ensure your token/SSH key has appropriate permissions

### Repository Structure Issues

**Problem**: `Repository does not contain configs/.amazonq/profiles/ directory`

**Solutions**:
1. Verify the repository has the correct directory structure
2. Check if you're using the correct branch
3. Ensure context files exist in `configs/.amazonq/profiles/*.md`

### No Context Files Found

**Problem**: `No context files (*.md) found`

**Solutions**:
1. Check that context files have `.md` extension
2. Verify files exist in `configs/.amazonq/profiles/` directory
3. Ensure files aren't empty or corrupted

## Advanced Usage

### Custom Installation Script

You can embed the repository URL in a custom install script:

```bash
#!/bin/bash
# install-acme-standards.sh

REPO="gitlab.acme.com/devtools/amazonq-standards"
BRANCH="main"

curl -sSL "https://$REPO/-/raw/$BRANCH/install.sh" | bash -s -- --repo "$REPO" --branch "$BRANCH" "$@"
```

### CI/CD Integration

For automated deployment:

```yaml
# .gitlab-ci.yml
deploy_standards:
  script:
    - ./install.sh --force --quiet --repo $CI_PROJECT_URL --branch $CI_COMMIT_REF_NAME
  only:
    - main
```

### Multiple Environments

```bash
# Development environment
./install.sh --repo gitlab.acme.com/devtools/amazonq-standards --branch develop

# Production environment  
./install.sh --repo gitlab.acme.com/devtools/amazonq-standards --branch main
```

## Security Considerations

1. **Always verify script source** before running with `curl | bash`
2. **Use specific branches/tags** instead of `main` for production
3. **Review rule changes** before installation in production environments
4. **Limit repository access** to authorized personnel only
5. **Regularly rotate** GitLab tokens and SSH keys

## Backup and Recovery

### Manual Backup

```bash
# Create manual backup
mkdir -p ~/.boomslang/backups
cp -r ~/.boomslang/*.md ~/.boomslang/backups/backup-$(date +%Y%m%d)/
```

### Restore from Backup

```bash
# List available backups
ls ~/.boomslang/backups/

# Restore from specific backup
cp -r ~/.boomslang/backups/backup-20240115/* ~/.boomslang/
```

### Recovery from Failed Installation

If installation fails mid-process:

```bash
# Check what was installed
ls -la ~/.boomslang/

# Remove partial installation
./boomslang-install.sh --uninstall --force

# Restore from backup if needed
cp -r ~/.boomslang/backups/backup-LATEST/* ~/.boomslang/

# Retry installation
./boomslang-install.sh --repo your-repo
```