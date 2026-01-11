# Contributing to Svrnty Marketplace

Thank you for your interest in contributing to the Svrnty Marketplace! This guide will help you add your Claude Code plugin to the marketplace.

## Prerequisites

Before submitting your plugin, ensure:

- ✅ Your plugin has a valid `.claude-plugin/plugin.json` manifest
- ✅ Your plugin is tested and stable
- ✅ You have comprehensive documentation
- ✅ Your plugin follows security best practices
- ✅ You have a GitHub repository for your plugin
- ✅ Your plugin has a clear license (MIT, Apache 2.0, etc.)

## Submission Process

### 1. Fork the Marketplace Repository

```bash
gh repo fork svrnty/svrnty-marketplace
cd svrnty-marketplace
```

### 2. Create Your Plugin Entry

Create a new directory under `plugins/` with your plugin slug:

```bash
mkdir -p plugins/your-plugin-name
```

### 3. Create Required Files

Each plugin entry must have:

#### `plugins/your-plugin-name/metadata.json`

```json
{
  "$schema": "../../schemas/plugin-entry.schema.json",
  "id": "your-plugin-name",
  "name": "Your Plugin Name",
  "slug": "your-plugin-name",
  "version": "1.0.0",
  "description": "Short one-sentence description",
  "long_description": "Detailed 1-2 paragraph description",
  "author": {
    "name": "Your Name or Organization",
    "email": "contact@example.com",
    "url": "https://example.com"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/your-org/your-plugin"
  },
  "license": "MIT",
  "categories": ["automation"],
  "keywords": ["claude-code", "plugin"],
  "platform": {
    "min_claude_code_version": "1.0.0",
    "supported_platforms": ["darwin", "linux", "win32"]
  },
  "status": "stable",
  "verified": false
}
```

See [schemas/plugin-entry.schema.json](./schemas/plugin-entry.schema.json) for full schema.

#### `plugins/your-plugin-name/README.md`

```markdown
# Your Plugin Name

Short description of your plugin.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

\`\`\`bash
claude-code plugin install svrnty/your-plugin-name
\`\`\`

## Usage

Brief usage instructions with examples.

## Documentation

Link to full documentation.
```

#### `plugins/your-plugin-name/CHANGELOG.md`

```markdown
# Changelog

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release
- Feature 1
- Feature 2
```

### 4. Add Entry to Marketplace Index

Edit `marketplace-index.json` and add your plugin to the `plugins` array:

```json
{
  "id": "your-plugin-name",
  "name": "Your Plugin Name",
  "slug": "your-plugin-name",
  "author": "Your Name",
  "repository": "https://github.com/your-org/your-plugin",
  "marketplace_entry": "./plugins/your-plugin-name/metadata.json",
  "version": "1.0.0",
  "description": "Short description",
  "categories": ["automation"],
  "tags": ["claude-code", "plugin"],
  "status": "stable",
  "verified": false
}
```

### 5. Add Screenshots (Optional but Recommended)

Create `plugins/your-plugin-name/assets/` directory and add:

- Screenshots (PNG/JPG, max 2MB each)
- Demo GIF (max 10MB)
- Icon (PNG, 256x256px)

Update `metadata.json` with asset URLs.

### 6. Validate Your Entry

Run validation locally:

```bash
# Install validation tools
npm install -g ajv-cli markdownlint-cli

# Validate schemas
ajv validate -s schemas/plugin-entry.schema.json -d plugins/your-plugin-name/metadata.json

# Validate markdown
markdownlint plugins/your-plugin-name/*.md
```

### 7. Submit Pull Request

```bash
git checkout -b add-your-plugin-name
git add plugins/your-plugin-name/ marketplace-index.json
git commit -m "Add your-plugin-name plugin"
git push origin add-your-plugin-name

# Create PR
gh pr create --title "Add Your Plugin Name" --body "Plugin submission for review"
```

## Review Process

1. **Automated Validation**: CI checks schema, required files, and security
2. **Manual Review**: Maintainers review code quality, documentation, security
3. **Approval**: Once approved, plugin is merged and published
4. **Verification**: High-quality plugins may receive verified badge

### Review Criteria

- **Functionality**: Plugin works as described
- **Documentation**: Clear installation and usage instructions
- **Security**: No vulnerabilities or malicious code
- **Quality**: Follows best practices, well-tested
- **Maintenance**: Active maintenance commitment

## Plugin Categories

Choose 1-5 categories:

- `automation` - Workflow and task automation
- `productivity` - Developer productivity tools
- `development-tools` - Code generation, refactoring, testing
- `project-management` - Agile, planning, tracking
- `agile` - Agile methodology and sprint management
- `integration` - External service integrations
- `ai-enhancement` - AI-powered development features

## Plugin Status

- `alpha` - Early development, may have bugs
- `beta` - Feature complete, testing phase
- `stable` - Production ready, recommended
- `deprecated` - No longer maintained

## Updating Your Plugin

To update your plugin:

1. Update version in your plugin's `plugin.json`
2. Update `plugins/your-plugin-name/metadata.json` version
3. Update `plugins/your-plugin-name/CHANGELOG.md`
4. Update marketplace-index.json version
5. Submit PR with update

## Getting Help

- **Questions**: Open a [Discussion](https://github.com/svrnty/svrnty-marketplace/discussions)
- **Issues**: Open an [Issue](https://github.com/svrnty/svrnty-marketplace/issues)
- **Email**: marketplace@svrnty.com

## Code of Conduct

Please follow our [Code of Conduct](./CODE_OF_CONDUCT.md) when contributing.

## License

By submitting a plugin to the marketplace, you agree that:

- Your plugin metadata is MIT licensed
- Your plugin code retains its original license
- You grant Svrnty permission to list and distribute your plugin

Thank you for contributing to the Claude Code ecosystem! 🎉
