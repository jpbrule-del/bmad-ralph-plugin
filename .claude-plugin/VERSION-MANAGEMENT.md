# Version Management Guide

Comprehensive guide for version management in the BMAD Ralph Plugin.

## Table of Contents

- [Overview](#overview)
- [Semantic Versioning](#semantic-versioning)
- [Version Management Scripts](#version-management-scripts)
- [Release Workflow](#release-workflow)
- [Rollback Workflow](#rollback-workflow)
- [Changelog Management](#changelog-management)
- [Marketplace Updates](#marketplace-updates)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The BMAD Ralph Plugin uses a comprehensive version management system that ensures:

- **Semantic Versioning**: Consistent version numbering following semver
- **Version Synchronization**: Automatic sync between package.json and plugin.json
- **Changelog Generation**: Automated changelog creation from git commits
- **Git Tagging**: Automatic release tagging for version history
- **Marketplace Updates**: Synchronized marketplace manifest updates
- **Safe Rollbacks**: Ability to revert to previous versions with backups

## Semantic Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

### Version Components

- **MAJOR**: Incompatible API changes (e.g., 1.0.0 → 2.0.0)
- **MINOR**: New features, backward compatible (e.g., 1.0.0 → 1.1.0)
- **PATCH**: Bug fixes, backward compatible (e.g., 1.0.0 → 1.0.1)
- **PRERELEASE**: Optional pre-release identifier (e.g., 1.0.0-beta.1)
- **BUILD**: Optional build metadata (e.g., 1.0.0+20130313144700)

### When to Bump Versions

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Breaking changes | MAJOR | 1.2.3 → 2.0.0 |
| New features | MINOR | 1.2.3 → 1.3.0 |
| Bug fixes | PATCH | 1.2.3 → 1.2.4 |
| Beta release | PRERELEASE | 1.2.3 → 1.3.0-beta.1 |

## Version Management Scripts

All version management scripts are located in `.claude-plugin/scripts/`:

### 1. version-sync.sh

Synchronizes version between package.json and plugin.json.

```bash
# Check if versions are in sync
./scripts/version-sync.sh --check

# Sync plugin.json from package.json
./scripts/version-sync.sh --from-package

# Sync package.json from plugin.json
./scripts/version-sync.sh --from-plugin

# Set both to version 1.2.0
./scripts/version-sync.sh --set 1.2.0
```

**Features**:
- Validates semver format
- Updates both files atomically
- Provides clear error messages
- Exit codes for CI/CD integration

### 2. changelog-generate.sh

Generates or updates changelog following Keep a Changelog format.

```bash
# Create new changelog entry for version 1.2.0
./scripts/changelog-generate.sh --new 1.2.0

# Generate changelog from git commits
./scripts/changelog-generate.sh --from-git 1.2.0

# Validate changelog format
./scripts/changelog-generate.sh --validate
```

**Features**:
- Follows [Keep a Changelog](https://keepachangelog.com/) format
- Parses conventional commit messages
- Categorizes changes (Added, Changed, Fixed, etc.)
- Syncs to marketplace automatically

### 3. release.sh

Automates the complete release process.

```bash
# Create release 1.2.0 (interactive)
./scripts/release.sh 1.2.0

# Dry run to preview changes
./scripts/release.sh --dry-run 1.2.0

# Release with auto-generated changelog
./scripts/release.sh --from-git 1.2.0

# Skip tests (not recommended)
./scripts/release.sh --skip-tests 1.2.0

# Skip marketplace update
./scripts/release.sh --skip-marketplace 1.2.0
```

**Release Process**:
1. ✅ Validates git repository state (clean working directory)
2. ✅ Runs quality gates (lint, test, build)
3. 📝 Bumps version in package.json and plugin.json
4. 📋 Updates or generates changelog
5. 💾 Commits version changes
6. 🏷️ Creates git tag
7. 📦 Updates marketplace manifest
8. 🚀 Pushes to remote (with confirmation)

### 4. marketplace-update.sh

Updates marketplace manifest and index.

```bash
# Sync all files to marketplace
./scripts/marketplace-update.sh --sync

# Update marketplace index with current version
./scripts/marketplace-update.sh --update-index

# Validate marketplace files
./scripts/marketplace-update.sh --validate
```

**Features**:
- Syncs plugin.json, marketplace.json, CHANGELOG.md, README.md
- Updates marketplace index version
- Validates JSON format and version consistency
- Provides comprehensive validation report

### 5. version-rollback.sh

Safely rolls back to a previous version.

```bash
# List available versions
./scripts/version-rollback.sh --list

# Rollback to version 1.0.0
./scripts/version-rollback.sh 1.0.0

# Dry run to preview changes
./scripts/version-rollback.sh --dry-run 1.0.0

# Force rollback without confirmation
./scripts/version-rollback.sh --force 1.0.0
```

**Rollback Process**:
1. 🔍 Validates target version exists in git tags
2. 🔄 Creates backup branch
3. ⏮️ Resets to target version tag
4. 📝 Updates version files
5. 💾 Creates rollback commit
6. 🚀 Optionally pushes to remote

## Release Workflow

### Standard Release

Follow these steps for a standard release:

#### 1. Prepare for Release

```bash
# Ensure you're on main branch
git checkout main
git pull origin main

# Verify versions are in sync
./.claude-plugin/scripts/version-sync.sh --check

# Validate changelog format
./.claude-plugin/scripts/changelog-generate.sh --validate
```

#### 2. Run Release Script

```bash
# For a minor version bump (new features)
./.claude-plugin/scripts/release.sh 1.2.0

# For a patch version bump (bug fixes)
./.claude-plugin/scripts/release.sh 1.1.1

# For a major version bump (breaking changes)
./.claude-plugin/scripts/release.sh 2.0.0
```

#### 3. Create GitHub Release

After the release script completes:

1. Go to: https://github.com/snarktank/ralph/releases/new?tag=vX.Y.Z
2. Fill in the release title: "vX.Y.Z - Release Name"
3. Copy relevant sections from CHANGELOG.md
4. Add release notes, screenshots, or additional context
5. Publish release

#### 4. Announce Release

- Update project README if needed
- Notify users via Discord/Slack/Twitter
- Update documentation site
- Close related issues and milestones

### Beta/Pre-Release

For beta or pre-release versions:

```bash
# Create beta release
./.claude-plugin/scripts/release.sh 1.3.0-beta.1

# Mark as pre-release on GitHub
# Test with early adopters
# Address feedback

# Release final version
./.claude-plugin/scripts/release.sh 1.3.0
```

### Hotfix Release

For urgent bug fixes:

```bash
# Create hotfix branch
git checkout -b hotfix/critical-bug

# Fix the bug and commit
git commit -m "fix: critical security vulnerability"

# Merge to main
git checkout main
git merge hotfix/critical-bug

# Release patch version
./.claude-plugin/scripts/release.sh 1.2.1
```

## Rollback Workflow

### When to Rollback

Rollback when:
- Critical bug discovered after release
- Breaking changes affecting users
- Security vulnerability introduced
- Failed deployment or distribution

### Rollback Process

#### 1. List Available Versions

```bash
./.claude-plugin/scripts/version-rollback.sh --list
```

#### 2. Test Rollback (Dry Run)

```bash
./.claude-plugin/scripts/version-rollback.sh --dry-run 1.1.0
```

#### 3. Execute Rollback

```bash
./.claude-plugin/scripts/version-rollback.sh 1.1.0
```

#### 4. Verify Rollback

```bash
# Check versions
./.claude-plugin/scripts/version-sync.sh --check

# Validate marketplace
./.claude-plugin/scripts/marketplace-update.sh --validate

# Test functionality
npm test
npm run build
```

#### 5. Communicate Rollback

- Update GitHub Release with rollback notice
- Notify users of the rollback and reason
- Provide timeline for fix and re-release
- Document lessons learned

### Recovering from Rollback

If you need to restore after a rollback:

```bash
# Find backup branch
git branch | grep backup-before-rollback

# Restore from backup
git checkout backup-before-rollback-20260111-143000

# Or revert the rollback commit
git revert HEAD
```

## Changelog Management

### Changelog Format

Follows [Keep a Changelog 1.0.0](https://keepachangelog.com/en/1.0.0/):

```markdown
# Changelog

## [Unreleased]

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes

## [1.2.0] - 2026-01-15

### Added
- Feature X
- Feature Y
```

### Manual vs Automated Changelog

**Manual Changelog**:
- More descriptive
- Captures user impact
- Better for major releases

```bash
# Create entry, then manually edit CHANGELOG.md
./.claude-plugin/scripts/changelog-generate.sh --new 1.2.0
```

**Automated Changelog**:
- Faster for rapid releases
- Good for patch versions
- Based on commit messages

```bash
# Generate from git commits
./.claude-plugin/scripts/changelog-generate.sh --from-git 1.2.0
```

### Commit Message Format

For best automated changelog generation, use conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

**Types**:
- `feat:` - New feature (→ Added)
- `fix:` - Bug fix (→ Fixed)
- `refactor:` - Code refactoring (→ Changed)
- `perf:` - Performance improvement (→ Changed)
- `security:` - Security fix (→ Security)
- `docs:` - Documentation only
- `test:` - Test updates
- `chore:` - Build/tooling changes

**Examples**:
```bash
git commit -m "feat(commands): add delete command with confirmation"
git commit -m "fix(hooks): resolve race condition in pre-commit hook"
git commit -m "security(mcp): encrypt API keys at rest"
```

## Marketplace Updates

### Automatic Updates

The release script automatically updates the marketplace:

```bash
# Marketplace is updated as part of release
./.claude-plugin/scripts/release.sh 1.2.0
```

### Manual Marketplace Sync

If you need to manually sync marketplace files:

```bash
# Sync all files
./.claude-plugin/scripts/marketplace-update.sh --sync

# Update index
./.claude-plugin/scripts/marketplace-update.sh --update-index

# Validate
./.claude-plugin/scripts/marketplace-update.sh --validate
```

### Marketplace Files

Updated files:
- `plugin.json` - Plugin manifest
- `marketplace.json` - Marketplace listing
- `CHANGELOG.md` - Release history
- `README.md` - Plugin documentation
- `marketplace-index.json` - Marketplace catalog

## Best Practices

### Version Management

1. **Always validate before release**
   ```bash
   ./.claude-plugin/scripts/version-sync.sh --check
   ./.claude-plugin/scripts/changelog-generate.sh --validate
   ```

2. **Use dry-run for testing**
   ```bash
   ./.claude-plugin/scripts/release.sh --dry-run 1.2.0
   ```

3. **Create meaningful changelog entries**
   - Focus on user impact
   - Explain breaking changes
   - Link to related issues/PRs

4. **Test before release**
   - Run all quality gates
   - Test in clean environment
   - Verify marketplace files

### Git Workflow

1. **Keep main branch clean**
   - All releases from main/master
   - Feature branches for development
   - Hotfix branches for urgent fixes

2. **Use descriptive commit messages**
   - Follow conventional commits
   - Include issue references
   - Explain the "why" not just "what"

3. **Tag releases consistently**
   - Always use `v` prefix (v1.2.0)
   - Include release notes in tag message
   - Push tags with commits

### Release Timing

1. **Regular release schedule**
   - Major: Quarterly (breaking changes)
   - Minor: Monthly (new features)
   - Patch: As needed (bug fixes)

2. **Avoid releasing on Fridays**
   - Issues may go unnoticed over weekend
   - Prefer Tuesday-Thursday releases

3. **Communication**
   - Announce releases in advance
   - Provide migration guides for breaking changes
   - Document known issues

## Troubleshooting

### Version Mismatch

**Problem**: Versions don't match between files

```bash
# Check current state
./.claude-plugin/scripts/version-sync.sh --check

# Fix by syncing from source of truth
./.claude-plugin/scripts/version-sync.sh --from-package
```

### Dirty Git Repository

**Problem**: Can't release with uncommitted changes

```bash
# Stash changes
git stash

# Or commit changes
git add .
git commit -m "chore: prepare for release"
```

### Failed Quality Gates

**Problem**: Tests or lint failing

```bash
# Fix issues first
npm run lint -- --fix
npm test

# Or skip tests (not recommended)
./.claude-plugin/scripts/release.sh --skip-tests 1.2.0
```

### Tag Already Exists

**Problem**: Version tag already exists

```bash
# List existing tags
git tag -l

# Delete local tag
git tag -d v1.2.0

# Delete remote tag (careful!)
git push origin :refs/tags/v1.2.0

# Or use a different version
./.claude-plugin/scripts/release.sh 1.2.1
```

### Marketplace Validation Failed

**Problem**: Marketplace files invalid

```bash
# Check validation errors
./.claude-plugin/scripts/marketplace-update.sh --validate

# Re-sync files
./.claude-plugin/scripts/marketplace-update.sh --sync

# Fix JSON errors manually
jq . marketplace-repo/marketplace-index.json
```

### Rollback Not Working

**Problem**: Can't rollback to previous version

```bash
# List available versions
./.claude-plugin/scripts/version-rollback.sh --list

# Check if tag exists
git tag -l | grep v1.1.0

# If tag missing, create from commit
git tag v1.1.0 <commit-hash>
```

### Build Failures After Release

**Problem**: Build breaks after version bump

```bash
# Rollback immediately
./.claude-plugin/scripts/version-rollback.sh 1.1.0

# Fix issues
npm install
npm run build

# Release again with patch version
./.claude-plugin/scripts/release.sh 1.2.1
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to release (e.g., 1.2.0)'
        required: true

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Run quality gates
        run: |
          npm run lint
          npm test
          npm run build

      - name: Release
        run: |
          ./.claude-plugin/scripts/release.sh ${{ github.event.inputs.version }}
        env:
          GIT_AUTHOR_NAME: GitHub Actions
          GIT_AUTHOR_EMAIL: actions@github.com
          GIT_COMMITTER_NAME: GitHub Actions
          GIT_COMMITTER_EMAIL: actions@github.com
```

## Support

For questions or issues with version management:

- **GitHub Issues**: https://github.com/snarktank/ralph/issues
- **Documentation**: https://github.com/snarktank/ralph#readme
- **Discord**: [Join our community](https://discord.gg/ralph)

## License

Version management scripts are part of the BMAD Ralph Plugin and follow the same MIT License.

---

**Last Updated**: 2026-01-11
**Version Management System Version**: 1.0.0
