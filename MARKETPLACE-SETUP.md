# Svrnty Marketplace Setup Guide

This guide explains how to set up the Svrnty Marketplace GitHub repository using the infrastructure created in the `marketplace-repo/` directory.

## Overview

STORY-033 requires creating the `github.com/svrnty/svrnty-marketplace` repository. Since AI agents cannot create GitHub repositories directly, this document provides step-by-step instructions for manual repository creation.

## Prerequisites

- GitHub account with access to create repositories under the `svrnty` organization (or your personal account for testing)
- Git CLI installed
- GitHub CLI (`gh`) installed (optional but recommended)

## Step 1: Create GitHub Repository

### Option A: Using GitHub Web Interface

1. Go to https://github.com/new (or https://github.com/organizations/svrnty/repositories/new for organization)
2. Fill in repository details:
   - **Repository name**: `svrnty-marketplace`
   - **Description**: "Official plugin marketplace for Claude Code plugins from Svrnty"
   - **Visibility**: Public
   - **Initialize repository**: Do NOT check any initialization options (no README, .gitignore, or license)
3. Click "Create repository"

### Option B: Using GitHub CLI

```bash
# For personal account
gh repo create svrnty-marketplace --public --description "Official plugin marketplace for Claude Code plugins from Svrnty"

# For organization (replace 'svrnty' with your org name)
gh repo create svrnty/svrnty-marketplace --public --description "Official plugin marketplace for Claude Code plugins from Svrnty"
```

## Step 2: Push Marketplace Infrastructure

Navigate to the marketplace repository directory and push all files:

```bash
# Navigate to marketplace repo directory
cd /Users/jean-philippebrule/Desktop/ralph/marketplace-repo

# Initialize git if not already initialized
git init

# Add GitHub remote (replace URL with your actual repository URL)
git remote add origin https://github.com/svrnty/svrnty-marketplace.git

# Or for SSH:
# git remote add origin git@github.com:svrnty/svrnty-marketplace.git

# Add all files
git add .

# Create initial commit
git commit -m "feat: Initial marketplace setup with bmad-ralph plugin

- Add marketplace structure and index
- Add bmad-ralph plugin entry
- Add CI workflows for validation and publishing
- Add contribution guidelines
- Add JSON schemas for validation"

# Push to main branch
git branch -M main
git push -u origin main
```

## Step 3: Configure GitHub Repository Settings

### Enable GitHub Pages

1. Go to repository Settings → Pages
2. Source: Deploy from a branch → `gh-pages` branch
3. Save

This enables the publish-index.yml workflow to deploy the marketplace website.

### Configure Secrets (Optional)

If using webhook notifications in CI:

1. Go to Settings → Secrets and variables → Actions
2. Add secret: `MARKETPLACE_WEBHOOK_URL`
   - Value: Your webhook endpoint URL

### Enable GitHub Actions

1. Go to Actions tab
2. Enable workflows if prompted
3. Verify workflows are running

## Step 4: Verify Setup

### Check Repository Structure

Verify the following structure exists:

```
svrnty-marketplace/
├── README.md
├── CONTRIBUTING.md
├── marketplace-index.json
├── plugins/
│   └── bmad-ralph/
│       ├── metadata.json
│       ├── README.md
│       └── CHANGELOG.md
├── schemas/
│   ├── marketplace-index.schema.json
│   └── plugin-entry.schema.json
└── .github/
    └── workflows/
        ├── validate-plugin.yml
        └── publish-index.yml
```

### Test CI Workflows

Create a test PR to verify validation works:

```bash
# Create test branch
git checkout -b test-validation

# Make a small change
echo "Test" >> README.md

# Commit and push
git add README.md
git commit -m "test: Verify CI validation"
git push origin test-validation

# Create PR
gh pr create --title "Test: Verify CI validation" --body "Testing automated validation"
```

Check that the `validate-plugin.yml` workflow runs successfully.

### Test Plugin Installation

Once the repository is set up, test installing the plugin:

```bash
# Install from marketplace
claude-code plugin install svrnty/bmad-ralph

# Or install from local repository
cd /path/to/bmad-ralph-plugin
claude-code plugin install .
```

## Step 5: Update Plugin Configuration

Update the `bmad-ralph-plugin` repository to reference the marketplace:

1. Update `.claude-plugin/marketplace.json` if needed
2. Add marketplace badge to README:
   ```markdown
   [![Marketplace](https://img.shields.io/badge/marketplace-svrnty-blue)](https://marketplace.svrnty.com/plugins/bmad-ralph)
   ```

## Maintenance

### Adding New Plugins

Follow the contribution guidelines in `CONTRIBUTING.md`:

1. Fork the repository
2. Add plugin entry under `plugins/your-plugin/`
3. Update `marketplace-index.json`
4. Submit pull request
5. CI validates automatically
6. Maintainers review and merge

### Updating Plugin Versions

To update a plugin version:

1. Update `plugins/plugin-name/metadata.json` version
2. Update `plugins/plugin-name/CHANGELOG.md`
3. Update `marketplace-index.json` entry version
4. Commit and push
5. CI publishes updated index

### Monitoring

- **CI Status**: Check Actions tab for workflow runs
- **Plugin Validation**: Review validation reports in PR checks
- **Usage Stats**: Track download counts in `marketplace-index.json`

## Troubleshooting

### CI Validation Fails

Check common issues:

- Invalid JSON schema (run `ajv validate` locally)
- Missing required files (metadata.json, README.md, CHANGELOG.md)
- Markdown linting errors (run `markdownlint` locally)

### GitHub Pages Not Deploying

Verify:

- GitHub Pages is enabled in repository settings
- `gh-pages` branch exists
- `publish-index.yml` workflow completed successfully
- Check workflow logs for errors

### Plugin Installation Fails

Check:

- Repository URL is correct in marketplace-index.json
- Plugin manifest is valid (validate with ajv)
- All dependencies are declared
- Claude Code version compatibility

## Support

For issues with:
- **Marketplace setup**: Open issue in svrnty-marketplace repo
- **Plugin development**: See plugin's repository
- **Claude Code**: See Claude Code documentation

## Next Steps

Once the repository is set up:

1. ✅ Repository created at github.com/svrnty/svrnty-marketplace
2. ✅ CI workflows running successfully
3. ✅ bmad-ralph plugin entry validated
4. ✅ Contributing guidelines documented
5. ✅ GitHub Pages deployed (optional)

You can now:
- Accept plugin submissions via pull requests
- Publish updated marketplace index on changes
- Track plugin downloads and ratings
- Maintain marketplace metadata

## Completion Criteria

STORY-033 is considered complete when:

- [x] Marketplace index structure created locally ✅
- [ ] GitHub repository created (manual step required)
- [x] bmad-ralph plugin entry added ✅
- [x] CI for validation configured ✅
- [x] Contribution process documented ✅
- [x] Marketplace metadata configured ✅

**Action Required**: Complete the manual GitHub repository creation step above to fully satisfy STORY-033 acceptance criteria.

## Files Created

This setup created the following files in `marketplace-repo/`:

- `README.md` - Marketplace overview
- `CONTRIBUTING.md` - Plugin submission guidelines
- `marketplace-index.json` - Master plugin index
- `plugins/bmad-ralph/metadata.json` - Plugin metadata
- `plugins/bmad-ralph/README.md` - Plugin description
- `plugins/bmad-ralph/CHANGELOG.md` - Version history
- `schemas/marketplace-index.schema.json` - Index validation schema
- `schemas/plugin-entry.schema.json` - Plugin validation schema
- `.github/workflows/validate-plugin.yml` - PR validation workflow
- `.github/workflows/publish-index.yml` - Index publishing workflow

All infrastructure is ready for deployment to GitHub.
