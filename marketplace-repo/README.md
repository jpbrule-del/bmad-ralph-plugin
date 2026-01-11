# Svrnty Marketplace

Official plugin marketplace for Claude Code plugins from Svrnty.

## Overview

The Svrnty Marketplace provides a curated collection of high-quality Claude Code plugins for development automation, productivity, and workflow enhancement.

## Available Plugins

- **[bmad-ralph](./plugins/bmad-ralph/)** - Autonomous development loop automation using the BMAD Method

## Installation

### Quick Install via Claude Code

```bash
# Install a plugin from the marketplace
claude-code plugin install svrnty/bmad-ralph
```

### Manual Installation

1. Browse available plugins in the `plugins/` directory
2. Follow the installation instructions in each plugin's README
3. Or clone the plugin repository and install locally

## For Plugin Developers

### Adding Your Plugin to the Marketplace

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed instructions on submitting plugins to the marketplace.

### Quick Steps

1. Ensure your plugin has a valid `plugin.json` manifest
2. Create a `marketplace.json` with marketplace metadata
3. Fork this repository
4. Add your plugin entry to `marketplace-index.json`
5. Submit a pull request

## Marketplace Structure

```
svrnty-marketplace/
├── README.md                    # This file
├── CONTRIBUTING.md              # Contribution guidelines
├── marketplace-index.json       # Master index of all plugins
├── plugins/                     # Plugin entries
│   └── bmad-ralph/
│       ├── metadata.json        # Plugin metadata
│       ├── README.md            # Plugin description
│       ├── CHANGELOG.md         # Version history
│       └── assets/              # Screenshots, demos
├── schemas/                     # JSON schemas
│   ├── plugin-entry.schema.json
│   └── marketplace-index.schema.json
└── .github/
    └── workflows/
        ├── validate-plugin.yml  # CI validation
        └── publish-index.yml    # Index publishing
```

## Quality Standards

All plugins in the Svrnty Marketplace must meet the following criteria:

- ✅ Valid `plugin.json` manifest
- ✅ Comprehensive documentation
- ✅ Security review passed
- ✅ No malicious code or vulnerabilities
- ✅ Proper dependency declarations
- ✅ Clear installation instructions
- ✅ Active maintenance commitment

## Plugin Categories

- **Automation** - Workflow and task automation
- **Productivity** - Developer productivity tools
- **Development Tools** - Code generation, refactoring, testing
- **Project Management** - Agile, planning, tracking
- **Integration** - External service integrations
- **AI Enhancement** - AI-powered development features

## Support

For issues with:
- **Specific plugins**: Open an issue in the plugin's repository
- **Marketplace itself**: Open an issue in this repository
- **Claude Code**: See [Claude Code documentation](https://docs.anthropic.com/claude-code)

## License

Individual plugins have their own licenses. See each plugin's repository for details.

The marketplace infrastructure is MIT licensed.

## Maintainers

- **Svrnty Team** - [@svrnty](https://github.com/svrnty)

## Links

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Plugin Development Guide](./docs/plugin-development.md)
- [Marketplace API](./docs/api.md)
