# BMAD Ralph Plugin - Installation Guide

**Version:** 1.0.0
**Last Updated:** 2026-01-11

This guide covers installation, verification, troubleshooting, and repair for the BMAD Ralph Plugin.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Methods](#installation-methods)
3. [Post-Installation Verification](#post-installation-verification)
4. [Troubleshooting](#troubleshooting)
5. [Repair Options](#repair-options)
6. [Uninstallation](#uninstallation)
7. [Upgrade Guide](#upgrade-guide)

---

## Prerequisites

### Required Dependencies

The BMAD Ralph Plugin requires the following system dependencies:

- **jq** (>= 1.6) - JSON processor
- **yq** (>= 4.0) - YAML processor
- **git** (>= 2.0) - Version control

### Installation Commands

#### macOS (Homebrew)

```bash
brew install jq yq git
```

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install jq git

# yq requires manual installation
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

#### Fedora/RHEL

```bash
sudo dnf install jq git

# yq requires manual installation
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

#### Windows (via WSL or Git Bash)

Follow Ubuntu/Debian instructions in WSL, or use Git Bash with manual installations.

### Optional: Perplexity API Key

For MCP (Model Context Protocol) features, set your Perplexity API key:

```bash
export PERPLEXITY_API_KEY='your-api-key-here'
```

Add to your shell profile for persistence:

```bash
echo 'export PERPLEXITY_API_KEY="your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

---

## Installation Methods

### Method 1: Marketplace Installation (Recommended)

1. **Open Claude Code**
2. **Browse Plugins:**
   ```
   /plugins browse
   ```
3. **Search for Ralph:**
   ```
   /plugins search bmad-ralph
   ```
4. **Install:**
   ```
   /plugins install bmad-ralph
   ```

### Method 2: Manual Installation

1. **Clone Repository:**
   ```bash
   cd ~/.claude-code/plugins
   git clone https://github.com/svrnty/bmad-ralph-plugin.git bmad-ralph
   ```

2. **Install Dependencies:**
   ```bash
   cd bmad-ralph
   npm install
   ```

3. **Verify Installation:**
   ```bash
   ./.claude-plugin/hooks/install-validate.sh
   ```

### Method 3: Development Installation

For plugin development:

```bash
# Clone repository
git clone https://github.com/svrnty/bmad-ralph-plugin.git
cd bmad-ralph-plugin

# Install dependencies
npm install

# Build plugin
npm run build

# Link for development
npm link
```

---

## Post-Installation Verification

### Automatic Validation

The plugin automatically runs validation on first load. You'll see:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BMAD Ralph Plugin - Installation Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/5] Checking plugin structure...
   ✓ Plugin structure complete

[2/5] Verifying commands...
   ✓ All 13 commands registered

[3/5] Verifying hooks...
   ✓ 12/16 hooks enabled

[4/5] Verifying dependencies...
   ✓ jq 1.6
   ✓ yq 4.30
   ✓ git 2.39

[5/5] Verifying MCP configuration...
   ✓ MCP configuration valid (1 server(s) configured)
   ⚠ PERPLEXITY_API_KEY not set (MCP features may not work)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Installation validation PASSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Manual Validation

Run validation manually anytime:

```bash
./.claude-plugin/hooks/install-validate.sh
```

### Verbose Output

For detailed validation logs:

```bash
RALPH_VALIDATION_VERBOSE=true ./.claude-plugin/hooks/install-validate.sh
```

### Check Installation Summary

View detailed plugin information:

```
/bmad-ralph:show
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Missing Dependencies

**Symptom:**
```
✗ jq (required: >= 1.6)
```

**Solution:**
Install missing dependencies using the platform-specific commands in [Prerequisites](#prerequisites).

#### Issue 2: Hook Permissions

**Symptom:**
```
⚠ Hook script not executable: verify-dependencies.sh
```

**Solution:**
Run the repair script (see [Repair Options](#repair-options)) or manually:
```bash
chmod +x .claude-plugin/hooks/*.sh
```

#### Issue 3: Invalid JSON Configuration

**Symptom:**
```
✗ plugin.json - Invalid JSON syntax
```

**Solution:**
1. Validate JSON manually:
   ```bash
   jq empty .claude-plugin/plugin.json
   ```
2. Fix syntax errors based on jq output
3. Re-run validation

#### Issue 4: MCP Server Not Connected

**Symptom:**
```
⚠ PERPLEXITY_API_KEY not set (MCP features may not work)
```

**Solution:**
Set the API key in your environment:
```bash
export PERPLEXITY_API_KEY='your-api-key-here'
```

For persistence, add to shell profile (~/.bashrc, ~/.zshrc).

#### Issue 5: Commands Not Registered

**Symptom:**
```
✗ Missing command: /bmad-ralph:init
```

**Solution:**
1. Check command file exists:
   ```bash
   ls -la .claude-plugin/commands/init.md
   ```
2. If missing, reinstall plugin or run repair script
3. Restart Claude Code to reload plugin

### Validation Logs

Check detailed validation logs:

```bash
cat .ralph-cache/validation.log
```

Logs include:
- Timestamp of each check
- Detailed error messages
- Component validation results

---

## Repair Options

### Automatic Repair

Run the automated repair script:

```bash
./.claude-plugin/hooks/install-repair.sh
```

The repair script will:
1. Check and create missing directories
2. Fix hook script permissions
3. Create cache directory
4. Validate JSON configuration files
5. Check MCP environment setup

**Sample Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BMAD Ralph Plugin - Installation Repair
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Repair] Checking directory structure...
  ✓ Directory structure OK

[Repair] Checking hook permissions...
  → Making executable: verify-dependencies.sh
  ✓ Fixed 1 hook permissions

[Repair] Checking cache directory...
  ✓ Cache directory OK

[Repair] Checking dependencies...
  ✓ All dependencies installed

[Repair] Validating JSON configuration files...
  ✓ All JSON files valid

[Repair] Checking MCP environment...
  ⚠ PERPLEXITY_API_KEY not set

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Repair Summary:
  Total repairs attempted: 6
  Successful: 5
  Failed: 1

⚠ Some repairs require manual intervention
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Manual Repair Steps

If automatic repair fails:

1. **Verify Plugin Structure:**
   ```bash
   ls -la .claude-plugin/
   ```
   Should contain: `commands/`, `skills/`, `agents/`, `hooks/`

2. **Check File Permissions:**
   ```bash
   find .claude-plugin/hooks -name "*.sh" -exec chmod +x {} \;
   ```

3. **Validate JSON Files:**
   ```bash
   jq empty .claude-plugin/plugin.json
   jq empty .claude-plugin/marketplace.json
   jq empty .claude-plugin/.mcp.json
   jq empty .claude-plugin/hooks/hooks.json
   ```

4. **Reinstall from Backup:**
   If all else fails, reinstall from marketplace:
   ```
   /plugins uninstall bmad-ralph
   /plugins install bmad-ralph
   ```

### Repair Logs

Check repair logs for details:

```bash
cat .ralph-cache/repair.log
```

---

## Uninstallation

### Marketplace Uninstallation

```
/plugins uninstall bmad-ralph
```

### Manual Uninstallation

1. **Remove Plugin Directory:**
   ```bash
   rm -rf ~/.claude-code/plugins/bmad-ralph
   ```

2. **Clean Cache (Optional):**
   ```bash
   rm -rf .ralph-cache
   ```

3. **Remove Ralph Data (Optional):**
   ```bash
   rm -rf ralph/
   ```

### Preserve Configuration

To keep your Ralph loops and configuration:

1. **Backup Ralph Data:**
   ```bash
   tar -czf ralph-backup.tar.gz ralph/
   ```

2. **Uninstall Plugin**

3. **Restore After Reinstall:**
   ```bash
   tar -xzf ralph-backup.tar.gz
   ```

---

## Upgrade Guide

### Automatic Upgrade

The plugin checks for updates automatically (configurable in `.claude-plugin/auto-update.json`):

```json
{
  "enabled": true,
  "check_interval": 86400,
  "auto_install": false
}
```

When an update is available:

```
[Update Available] BMAD Ralph Plugin v1.1.0

Release Notes:
- New feature: Enhanced loop optimization
- Bug fix: Improved error handling

Actions:
  [U] Update now
  [D] Defer (remind tomorrow)
  [S] Skip this version
  [V] View full changelog
```

### Manual Upgrade

#### Via Marketplace

```
/plugins update bmad-ralph
```

#### Manual Update

```bash
cd ~/.claude-code/plugins/bmad-ralph
git pull origin main
npm install
npm run build
```

### Upgrade Verification

After upgrade, verify installation:

```bash
./.claude-plugin/hooks/install-validate.sh
```

### Rollback

If upgrade causes issues:

```bash
./.claude-plugin/scripts/version-rollback.sh
```

See [VERSION-MANAGEMENT.md](../VERSION-MANAGEMENT.md) for details.

---

## Getting Help

### Documentation

- **Quick Start:** [README.md](../README.md)
- **Command Reference:** [MCP-USAGE.md](./MCP-USAGE.md)
- **Hook Configuration:** [Hook Execution Engine](./hooks/README.md)
- **Version Management:** [VERSION-MANAGEMENT.md](../VERSION-MANAGEMENT.md)

### Support Channels

- **GitHub Issues:** https://github.com/svrnty/bmad-ralph-plugin/issues
- **Discussion Forum:** https://github.com/svrnty/bmad-ralph-plugin/discussions

### Validation Commands

```bash
# Run validation
./.claude-plugin/hooks/install-validate.sh

# Run repair
./.claude-plugin/hooks/install-repair.sh

# View validation logs
cat .ralph-cache/validation.log

# View repair logs
cat .ralph-cache/repair.log
```

---

## Next Steps

After successful installation:

1. **Initialize Ralph in Your Project:**
   ```
   /bmad-ralph:init
   ```

2. **Create Your First Loop:**
   ```
   /bmad-ralph:create my-first-loop
   ```

3. **Run the Loop:**
   ```
   /bmad-ralph:run my-first-loop
   ```

4. **Monitor Progress:**
   ```
   /bmad-ralph:status my-first-loop
   ```

---

## Appendix

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PERPLEXITY_API_KEY` | Perplexity API key for MCP features | (none) |
| `RALPH_VALIDATION_VERBOSE` | Enable verbose validation output | `false` |
| `RALPH_BYPASS_HOOKS` | Bypass hook execution (emergency) | `false` |
| `RALPH_NOTIFICATION_WEBHOOK` | Webhook URL for notifications | (none) |
| `RALPH_AUTO_PICKUP_NEXT` | Auto-pickup next story after completion | `false` |

### File Locations

| Path | Description |
|------|-------------|
| `.claude-plugin/` | Plugin root directory |
| `.claude-plugin/plugin.json` | Plugin manifest |
| `.claude-plugin/commands/` | Command definitions |
| `.claude-plugin/hooks/` | Hook scripts |
| `.ralph-cache/` | Runtime cache and logs |
| `ralph/` | User's Ralph loops and data |

### Default Configuration

See [ralph/config.yaml.example](../ralph/config.yaml.example) for configuration options.

---

**Happy Automating! 🚀**
