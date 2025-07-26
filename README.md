# Boomslang: Amazon Q CLI Standards Manager

Boomslang is a template repository that organizations can fork and customize to distribute their Amazon Q Developer CLI standards. It provides a simple way to define custom context profiles and distribute them via a lightweight install script.

## Quick Start

### For End Users

```bash
# Zero-config installation (recommended)
./boomslang-install.sh

# Or download and run in one step
curl -sSL https://gitlab.yourorg.com/devtools/amazonq-standards/-/raw/main/boomslang-install.sh | bash
```

### For Organizations

1. **Fork this repository**
2. **Configure the install script** by setting `ORG_REPO_URL` in `boomslang-install.sh`
3. **Customize the context files** in `configs/.amazonq/profiles/`
4. **Update configuration** in `install-config.json`
5. **Validate profiles** with `./scripts/validate-profiles.sh`
6. **Distribute** the pre-configured install script to your team

## What's Included

- **👥 Multiple Profiles**: Role-based profiles (engineer, reviewer, architect) with specialized contexts
- **📋 Context Rules**: Keyword-activated AI behavior for different development workflows  
- **🔧 Install Script**: Lightweight installer with dry-run, uninstall, and authentication support
- **✅ Validation**: Rule quality checking and syntax validation
- **📚 Documentation**: Comprehensive guides for setup and customization

## Key Features

- ✅ **Zero-Config Installation**: Pre-configured by maintainers, users just run the script
- ✅ **GitLab Integration**: Uses `glab` CLI with SSH fallback for private repositories
- ✅ **Dry Run Mode**: See what would be installed without making changes  
- ✅ **Clean Install**: Replaces existing profiles with latest versions
- ✅ **Clean Uninstall**: Complete removal with confirmation prompts
- ✅ **Cross-Platform**: Works on macOS and Linux

## Project Structure

```
├── configs/.amazonq/profiles/  # Context files for Amazon Q profiles
│   ├── engineer-context.md     # Engineering development context
│   ├── reviewer-context.md     # Code review and analysis context  
│   └── architect-context.md    # System architecture context
├── scripts/                    # Utility scripts
│   └── validate-profiles.sh    # Profile validation
├── docs/                       # Documentation
│   └── installation-guide.md   # Detailed installation guide
├── boomslang-install.sh        # Main installation script
└── install-config.json         # Configuration template
```

## Documentation

- **[Goals & Requirements](GOALS_AND_REQUIREMENTS.md)** - Project overview and specifications
- **[Installation Guide](docs/installation-guide.md)** - Detailed setup and usage instructions
- **[Scripts Documentation](scripts/README.md)** - Maintainer tools and workflows

## Authentication

The installer supports two authentication methods for private repositories:

### GitLab CLI (Recommended)
```bash
glab auth login --hostname gitlab.yourorg.com
```

### SSH Keys
```bash
ssh-keygen -t ed25519 -C "your.email@yourorg.com"
# Add public key to GitLab settings
```

## Example Usage

```bash
# Zero-config installation (most common)
./boomslang-install.sh

# Dry run to see what would be installed
./boomslang-install.sh --dry-run

# Override repository for testing
./boomslang-install.sh --repo gitlab.acme.com/devtools/amazonq-standards-dev

# Uninstall with confirmation
./boomslang-install.sh --uninstall

# Force uninstall without prompts
./boomslang-install.sh --uninstall --force
```

### Using Profiles

After installation, profiles are available in Amazon Q:

```bash
# Start Amazon Q chat
q chat

# Switch to engineer profile for development tasks
/profile set engineer

# Switch to reviewer profile for code reviews  
/profile set reviewer

# Switch to architect profile for system design
/profile set architect
```

## Contributing

This is a template repository. Organizations should:

1. Fork this repository
2. Customize for their needs
3. Maintain their own version

For improvements to the template itself, please open issues or pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

- Check the [Installation Guide](docs/installation-guide.md) for troubleshooting
- Review [Scripts Documentation](scripts/README.md) for maintainer workflows
- Open issues for bugs or feature requests