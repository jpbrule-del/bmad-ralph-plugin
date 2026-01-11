# BMAD Ralph Plugin - Auto-Update System

Comprehensive guide to the automatic update system for keeping your Ralph plugin up-to-date with the latest features and fixes.

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [Update Workflow](#update-workflow)
- [Manual Operations](#manual-operations)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## Overview

The Ralph Plugin Auto-Update System provides:

- **Automatic Update Checks**: Periodic checks for new versions based on configurable interval
- **User Notifications**: Clear notifications when updates are available
- **One-Click Updates**: Simple installation process with configuration preservation
- **Update Deferral**: Ability to postpone updates for a specified period
- **Changelog Display**: View release notes before updating
- **Configuration Preservation**: User settings are backed up and restored during updates
- **Rollback Support**: Automatic backups enable rollback if needed

## Configuration

### Configuration File

Auto-update settings are stored in `.claude-plugin/auto-update.json`:

```json
{
  "enabled": true,
  "check_interval_hours": 24,
  "auto_install": false,
  "update_channel": "stable",
  "backup_before_update": true,
  "notify_method": "console"
}
```

### Configuration Options

#### Core Settings

- **`enabled`** (boolean, default: `true`)
  - Enable/disable auto-update checks
  - Set to `false` to completely disable update checking

- **`check_interval_hours`** (number, default: `24`)
  - Hours between automatic update checks
  - Common values: `24` (daily), `168` (weekly), `720` (monthly)
  - Set to `0` to check on every plugin load (not recommended)

- **`auto_install`** (boolean, default: `false`)
  - Automatically install updates without user confirmation
  - **Recommended**: Keep `false` for manual control
  - When `true`, updates install immediately after check

- **`update_channel`** (string, default: `"stable"`)
  - Update channel to follow
  - Options: `"stable"`, `"beta"`, `"dev"`
  - Most users should use `"stable"`

#### Backup Settings

- **`backup_before_update`** (boolean, default: `true`)
  - Create backup before installing updates
  - **Strongly recommended**: Keep `true` for rollback capability
  - Backups stored in `ralph/.update-backups/`

- **`preserve_configuration.files`** (array)
  - Files to preserve during update
  - Default: `["ralph/config.yaml", ".claude-plugin/auto-update.json", ".claude-plugin/hooks/hooks.json"]`
  - Add custom configuration files here

- **`preserve_configuration.directories`** (array)
  - Directories to preserve during update
  - Default: `["ralph/loops", "ralph/archive"]`
  - Your loop data is always preserved

#### Update Source

- **`update_source.type`** (string, default: `"github"`)
  - Source for updates
  - Options: `"github"`, `"marketplace"`, `"custom"`

- **`update_source.repository`** (string)
  - Repository for GitHub updates
  - Default: `"snarktank/ralph"`

- **`update_source.api_endpoint`** (string)
  - API endpoint for checking updates
  - Default: GitHub releases API

#### Display Settings

- **`changelog_display.show_on_notify`** (boolean, default: `true`)
  - Show changelog when notifying of updates
  - Set to `false` for minimal notifications

- **`changelog_display.max_lines`** (number, default: `50`)
  - Maximum lines to display in changelog
  - Larger changelogs are truncated

## Update Workflow

### Automatic Update Check (Plugin Load)

1. **Trigger**: Plugin loads (startup, commands)
2. **Check Interval**: Respects `check_interval_hours` setting
3. **Version Comparison**: Compares current version with latest release
4. **Deferral Check**: Skips if version is deferred
5. **Notification**: Displays update available message with changelog

### Update Notification

When an update is available, you'll see:

```
═══════════════════════════════════════════════════════════════
   BMAD Ralph Plugin Update Available
═══════════════════════════════════════════════════════════════

  Current Version: 1.0.0
  Latest Version:  1.1.0

  Release Notes: https://github.com/snarktank/ralph/releases/tag/v1.1.0

  To update:
    claude-plugin install --update bmad-ralph

  Or run:
    .claude-plugin/scripts/auto-update-install.sh

  To defer this update:
    .claude-plugin/scripts/auto-update-defer.sh 1.1.0

═══════════════════════════════════════════════════════════════
```

### Update Installation Process

1. **Backup Creation**
   - Current configuration backed up to `ralph/.update-backups/`
   - Includes all files/directories in `preserve_configuration`

2. **Download Update**
   - Fetches latest version from update source
   - Verifies download integrity

3. **Configuration Preservation**
   - User settings temporarily stored
   - Custom hooks, skills, and configuration preserved

4. **Installation**
   - Plugin files replaced with new version
   - Migration scripts executed if needed

5. **Configuration Restoration**
   - User settings restored
   - Custom configurations merged

6. **Changelog Display**
   - Shows what's new in the updated version

7. **Completion**
   - Backup location provided
   - Restart instructions given

## Manual Operations

### Check for Updates (Force)

Force an immediate update check, ignoring interval:

```bash
.claude-plugin/scripts/auto-update-check.sh --force
```

### Install Update

Install the latest version:

```bash
.claude-plugin/scripts/auto-update-install.sh
```

Install a specific version:

```bash
.claude-plugin/scripts/auto-update-install.sh 1.1.0
```

### Defer Update

Defer an update for 7 days (default):

```bash
.claude-plugin/scripts/auto-update-defer.sh 1.1.0
```

Defer for a custom period:

```bash
.claude-plugin/scripts/auto-update-defer.sh 1.1.0 30  # 30 days
```

### View Changelog

View changelog for latest version:

```bash
.claude-plugin/scripts/auto-update-changelog.sh
```

View changelog for specific version:

```bash
.claude-plugin/scripts/auto-update-changelog.sh 1.1.0
```

### Cancel Deferred Update

Remove deferral for a version:

```bash
jq 'del(.deferred_updates["1.1.0"])' .claude-plugin/auto-update.json > .claude-plugin/auto-update.json.tmp
mv .claude-plugin/auto-update.json.tmp .claude-plugin/auto-update.json
```

### Disable Auto-Update

Temporarily disable auto-update checks:

```bash
jq '.enabled = false' .claude-plugin/auto-update.json > .claude-plugin/auto-update.json.tmp
mv .claude-plugin/auto-update.json.tmp .claude-plugin/auto-update.json
```

Re-enable:

```bash
jq '.enabled = true' .claude-plugin/auto-update.json > .claude-plugin/auto-update.json.tmp
mv .claude-plugin/auto-update.json.tmp .claude-plugin/auto-update.json
```

## Security

### Credential Handling

- **No Credentials Required**: Basic update checks require no authentication
- **Private Repositories**: Configure `GITHUB_TOKEN` environment variable if needed
- **API Rate Limits**: Anonymous GitHub API limited to 60 requests/hour

### Update Verification

- **Source Verification**: Updates fetched from configured trusted source
- **Integrity Checks**: Checksums verified before installation (when available)
- **HTTPS Only**: All update communications use HTTPS

### Configuration Backup

- **Automatic Backups**: Created before every update
- **Backup Location**: `ralph/.update-backups/backup-VERSION-TIMESTAMP/`
- **Retention**: Backups kept indefinitely (manual cleanup recommended)

### Rollback Process

If an update causes issues, rollback to previous version:

```bash
# Find your backup
ls ralph/.update-backups/

# Use version-rollback script
.claude-plugin/scripts/version-rollback.sh 1.0.0
```

## Troubleshooting

### Update Check Not Running

**Problem**: No update notifications appearing

**Solutions**:

1. Check if auto-update is enabled:
   ```bash
   jq '.enabled' .claude-plugin/auto-update.json
   ```

2. Check last check timestamp:
   ```bash
   jq '.last_check_timestamp' .claude-plugin/auto-update.json
   ```

3. Force update check:
   ```bash
   .claude-plugin/scripts/auto-update-check.sh --force
   ```

4. Check logs:
   ```bash
   tail -n 50 ralph/logs/auto-update.log
   ```

### Update Check Fails

**Problem**: Error checking for updates

**Solutions**:

1. Verify internet connectivity:
   ```bash
   curl -I https://api.github.com/
   ```

2. Check GitHub API rate limit:
   ```bash
   curl https://api.github.com/rate_limit
   ```

3. Review error in logs:
   ```bash
   grep ERROR ralph/logs/auto-update.log
   ```

### Update Installation Fails

**Problem**: Update installation encounters errors

**Solutions**:

1. Check available disk space:
   ```bash
   df -h
   ```

2. Verify write permissions:
   ```bash
   ls -la .claude-plugin/
   ```

3. Review installation log:
   ```bash
   tail -n 100 ralph/logs/auto-update.log
   ```

4. Restore from backup if needed:
   ```bash
   ls ralph/.update-backups/
   .claude-plugin/scripts/version-rollback.sh <version>
   ```

### Configuration Not Preserved

**Problem**: Settings lost after update

**Solutions**:

1. Check backup exists:
   ```bash
   ls -la ralph/.update-backups/
   ```

2. Manually restore configuration:
   ```bash
   cp ralph/.update-backups/backup-*/ralph/config.yaml ralph/config.yaml
   ```

3. Verify preservation settings:
   ```bash
   jq '.preserve_configuration' .claude-plugin/auto-update.json
   ```

## Advanced Usage

### Custom Update Source

Configure a custom update source:

```json
{
  "update_source": {
    "type": "custom",
    "api_endpoint": "https://your-server.com/api/ralph/latest"
  }
}
```

### Beta Channel

Switch to beta releases for early features:

```json
{
  "update_channel": "beta"
}
```

### Automated Updates in CI/CD

For automated environments:

```json
{
  "auto_install": true,
  "check_interval_hours": 1,
  "backup_before_update": true
}
```

### Custom Preservation Rules

Add custom files to preserve:

```json
{
  "preserve_configuration": {
    "files": [
      "ralph/config.yaml",
      ".claude-plugin/auto-update.json",
      "custom/my-config.json"
    ],
    "directories": [
      "ralph/loops",
      "ralph/archive",
      "custom/data"
    ]
  }
}
```

### Integration with Hooks

The auto-update check runs as a `plugin-load` hook. To modify behavior:

1. Edit `.claude-plugin/hooks/hooks.json`
2. Find `auto-update-check` hook
3. Adjust `timeout`, `enabled`, or `execution_order`

### Monitoring Update Activity

View update check history:

```bash
grep "auto-update-check" ralph/logs/auto-update.log
```

View update installation history:

```bash
grep "Update installation" ralph/logs/auto-update.log
```

## Best Practices

1. **Keep Enabled**: Leave auto-update checks enabled for security patches
2. **Review Changelogs**: Always review what's changing before updating
3. **Test After Update**: Verify loops run correctly after updating
4. **Maintain Backups**: Don't delete backup directories immediately
5. **Update Regularly**: Don't defer updates indefinitely
6. **Monitor Logs**: Periodically check `ralph/logs/auto-update.log`
7. **Stable Channel**: Use stable channel for production environments

## Related Documentation

- [Version Management](VERSION-MANAGEMENT.md) - Versioning and release process
- [MCP Security](MCP-SECURITY.md) - Credential handling and security
- [Hooks System](HOOKS-README.md) - Hook execution and configuration

## Support

If you encounter issues with auto-update:

1. Check logs: `ralph/logs/auto-update.log`
2. Review troubleshooting section above
3. File issue: https://github.com/snarktank/ralph/issues
4. Include log excerpts and configuration (redact sensitive data)

---

**Last Updated**: 2026-01-11
**Version**: 1.0.0
**Status**: Implemented (STORY-035)
