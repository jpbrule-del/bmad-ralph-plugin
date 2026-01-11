# MCP Security Guide

## Overview

This document describes the comprehensive security measures implemented for MCP (Model Context Protocol) integration in the BMAD Ralph Plugin. Security is a top priority for protecting API credentials and ensuring safe external service integration.

## Table of Contents

- [Security Features](#security-features)
- [Credential Storage](#credential-storage)
- [Credential Encryption](#credential-encryption)
- [Validation & Verification](#validation--verification)
- [Logging Protection](#logging-protection)
- [Network Security](#network-security)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Security Features

### ✅ Implemented Security Measures

1. **Credential Encryption at Rest**
   - GPG-based encryption for stored credentials
   - OS keychain integration (macOS/Linux/Windows)
   - Claude Code credential store support
   - File permissions restricted to owner (600)

2. **Never Log Credentials**
   - Automatic log sanitization
   - Pattern-based credential redaction
   - Real-time log monitoring and sanitization
   - Backup protection for log files

3. **Startup Validation**
   - Credential validation on plugin load
   - Clear error messages for missing credentials
   - Support for environment variables
   - Support for Claude Code credential store

4. **Secure Transmission**
   - HTTPS-only connections
   - Domain allowlist enforcement
   - Certificate validation
   - Rate limiting and backoff

5. **Access Control**
   - Environment variable isolation
   - Process-level credential access
   - No credential sharing between plugins
   - Audit logging for credential access

---

## Credential Storage

### Storage Methods

#### 1. Environment Variables (Recommended)

**Setup:**
```bash
# Add to shell profile (~/.zshrc, ~/.bashrc, etc.)
export PERPLEXITY_API_KEY="your-api-key-here"

# Reload shell
source ~/.zshrc
```

**Pros:**
- ✅ Simple to set up
- ✅ Process-isolated
- ✅ No file storage required
- ✅ Standard practice

**Cons:**
- ❌ Visible in process list
- ❌ Not encrypted at rest
- ❌ Requires manual setup

#### 2. Claude Code Credential Store

**Setup:**
```bash
# Store credential using Claude CLI
claude config set-credential PERPLEXITY_API_KEY

# Verify storage
claude config get-credential PERPLEXITY_API_KEY
```

**Pros:**
- ✅ Encrypted at rest
- ✅ Integrated with Claude Code
- ✅ Secure retrieval
- ✅ Cross-platform support

**Cons:**
- ❌ Requires Claude Code CLI
- ❌ Additional setup step

#### 3. OS Keychain Integration

**macOS Keychain:**
```bash
# Store using credential manager
.claude-plugin/hooks/mcp-credential-manager.sh store PERPLEXITY_API_KEY "your-key"

# Enable keychain support
export USE_OS_KEYCHAIN=true
```

**Linux Secret Service:**
```bash
# Requires secret-tool
sudo apt-get install libsecret-tools

# Store credential
.claude-plugin/hooks/mcp-credential-manager.sh store PERPLEXITY_API_KEY "your-key"

export USE_OS_KEYCHAIN=true
```

**Windows Credential Manager:**
```bash
# Store credential
.claude-plugin/hooks/mcp-credential-manager.sh store PERPLEXITY_API_KEY "your-key"

export USE_OS_KEYCHAIN=true
```

**Pros:**
- ✅ OS-level encryption
- ✅ Secure storage
- ✅ Integration with system security
- ✅ Persistent across sessions

**Cons:**
- ❌ Platform-specific
- ❌ Additional dependencies
- ❌ Setup complexity

#### 4. GPG-Encrypted File Storage

**Setup:**
```bash
# Install GPG
brew install gnupg  # macOS
sudo apt-get install gnupg  # Ubuntu

# Generate GPG key (if needed)
gpg --gen-key

# Store encrypted credential
.claude-plugin/hooks/mcp-credential-manager.sh store PERPLEXITY_API_KEY "your-key"
```

**Pros:**
- ✅ Strong encryption (GPG)
- ✅ File-based storage
- ✅ Portable across systems
- ✅ No special dependencies

**Cons:**
- ❌ Requires GPG setup
- ❌ Key management overhead
- ❌ Decryption on each use

---

## Credential Encryption

### Encryption Architecture

```
┌─────────────────────┐
│  Plain Credential   │
└──────────┬──────────┘
           │
           v
┌─────────────────────┐
│  Encryption Layer   │
│  - GPG/PGP          │
│  - AES-256          │
│  - OS Keychain      │
└──────────┬──────────┘
           │
           v
┌─────────────────────┐
│ Encrypted Storage   │
│ - File (600 perms)  │
│ - OS Keychain       │
│ - Claude Store      │
└─────────────────────┘
```

### Encryption Methods

#### GPG Encryption

**Key Features:**
- AES-256 encryption
- Public/private key cryptography
- Industry-standard security
- Cross-platform support

**Configuration:**
```bash
# Set encryption key (optional, defaults to $USER)
export MCP_ENCRYPTION_KEY="your-gpg-key-id"

# Store credential
.claude-plugin/hooks/mcp-credential-manager.sh store PERPLEXITY_API_KEY "key"
```

**File Location:**
```
.claude-plugin/.ralph-cache/mcp-credentials.enc
```

**File Permissions:**
```
-rw------- (600) - Owner read/write only
```

#### OS Keychain Encryption

**macOS Security Framework:**
- Uses Keychain Services API
- AES-256-GCM encryption
- Protected by user login keychain
- Automatic locking on logout

**Linux Secret Service:**
- Uses D-Bus Secret Service API
- Encrypted with user session key
- Integration with GNOME Keyring/KWallet
- Automatic locking on logout

**Windows Credential Manager:**
- Uses Windows Credential Vault
- DPAPI encryption
- Protected by user credentials
- Automatic locking on logout

---

## Validation & Verification

### Startup Validation

**Automatic Validation:**

The plugin automatically validates credentials on startup using the `mcp-credential-validator.sh` hook.

**Validation Process:**

1. **Parse Configuration**
   - Read `.mcp.json` for required credentials
   - Check validation settings

2. **Check Environment Variables**
   - Verify each required variable is set
   - Validate values are non-empty
   - NEVER log actual values

3. **Check Credential Store**
   - Query Claude Code credential store
   - Query OS keychain (if enabled)
   - Check encrypted file storage

4. **Report Results**
   - Show validation summary
   - Provide clear error messages
   - Suggest remediation steps

**Configuration:**

```json
{
  "authentication": {
    "validation": {
      "validate_on_startup": true,
      "fail_on_missing_credentials": false,
      "show_credential_warnings": true
    }
  }
}
```

**Validation Modes:**

| Mode | Behavior | Use Case |
|------|----------|----------|
| `fail_on_missing_credentials: true` | Block plugin load | Production environments |
| `fail_on_missing_credentials: false` | Warn and continue | Development/testing |
| `validate_on_startup: false` | Skip validation | Offline mode |

### Manual Validation

**Validate All Credentials:**
```bash
# Run validator directly
.claude-plugin/hooks/mcp-credential-validator.sh

# Or use credential manager
.claude-plugin/hooks/mcp-credential-manager.sh validate
```

**Check Specific Credential:**
```bash
# Retrieve credential (for testing)
.claude-plugin/hooks/mcp-credential-manager.sh retrieve PERPLEXITY_API_KEY
```

---

## Logging Protection

### Automatic Log Sanitization

**Security Policy: NEVER log credentials in plain text**

#### Real-Time Sanitization

The `mcp-log-sanitizer.sh` script provides automatic credential redaction.

**Features:**
- Pattern-based credential detection
- Real-time log monitoring
- Automatic redaction
- Backup protection

**Redaction Patterns:**

```regex
# API Keys
PERPLEXITY_API_KEY=[^[:space:]]*
API_KEY=[^[:space:]]*

# Tokens
Bearer [A-Za-z0-9_.-]+

# Passwords
password[[:space:]]*[:=][[:space:]]*[^[:space:]]+

# Secrets
secret[[:space:]]*[:=][[:space:]]*[^[:space:]]+

# Private Keys
-----BEGIN.*PRIVATE KEY-----.*-----END.*PRIVATE KEY-----

# Authorization Headers
Authorization:[[:space:]]*[^[:space:]]+
```

### Usage

**Sanitize Log File:**
```bash
.claude-plugin/hooks/mcp-log-sanitizer.sh sanitize ralph/logs/mcp-usage.log
```

**Check for Credentials:**
```bash
.claude-plugin/hooks/mcp-log-sanitizer.sh check ralph/logs/mcp-usage.log
```

**Scan Directory:**
```bash
.claude-plugin/hooks/mcp-log-sanitizer.sh scan ralph/logs/
```

**Watch in Real-Time:**
```bash
.claude-plugin/hooks/mcp-log-sanitizer.sh watch ralph/logs/mcp-usage.log
```

### Log Security Configuration

**In `.mcp.json`:**
```json
{
  "security": {
    "never_log_credentials": true,
    "sanitize_logs_on_write": true
  }
}
```

**Logging Best Practices:**
- ✅ Log credential names (e.g., "PERPLEXITY_API_KEY")
- ✅ Log validation success/failure
- ✅ Log credential access events
- ❌ NEVER log credential values
- ❌ NEVER log partial credentials
- ❌ NEVER log credential hashes

---

## Network Security

### HTTPS Enforcement

**All MCP requests use HTTPS only**

```json
{
  "security": {
    "allowed_domains": [
      "api.perplexity.ai",
      "*.anthropic.com"
    ]
  }
}
```

### Domain Allowlist

**Only allowed domains can receive credentials**

- `api.perplexity.ai` - Perplexity AI API
- `*.anthropic.com` - Claude/Anthropic services

**Configuration:**
```json
{
  "security": {
    "allowed_domains": [
      "api.perplexity.ai",
      "*.anthropic.com",
      "your-custom-domain.com"
    ]
  }
}
```

### Certificate Validation

**Automatic SSL/TLS certificate validation**

- Valid certificate chain required
- Expired certificates rejected
- Self-signed certificates rejected (unless explicitly allowed)

### Rate Limiting

**Protection against credential leakage via excessive requests**

```json
{
  "servers": {
    "perplexity": {
      "rate_limiting": {
        "enabled": true,
        "requests_per_minute": 10,
        "burst_size": 5
      }
    }
  }
}
```

---

## Best Practices

### Credential Management

#### ✅ DO:

1. **Use Environment Variables**
   - Store credentials in environment variables
   - Add to shell profile for persistence
   - Use Claude Code credential store

2. **Encrypt at Rest**
   - Enable GPG encryption
   - Use OS keychain
   - Set file permissions to 600

3. **Rotate Regularly**
   - Change API keys periodically
   - Use different keys for dev/prod
   - Revoke compromised keys immediately

4. **Monitor Access**
   - Review credential usage logs
   - Check for unauthorized access
   - Alert on anomalies

5. **Validate on Startup**
   - Enable startup validation
   - Fix missing credentials promptly
   - Monitor validation failures

#### ❌ DON'T:

1. **Never Commit Credentials**
   - Don't add to `.env` files in git
   - Don't hardcode in configuration
   - Don't store in plain text files

2. **Never Share Credentials**
   - Don't share via email/chat
   - Don't reuse across projects
   - Don't use personal keys for team projects

3. **Never Log Credentials**
   - Don't log during debugging
   - Don't include in error messages
   - Don't print to console

4. **Never Transmit Insecurely**
   - Don't use HTTP (always HTTPS)
   - Don't send via unencrypted channels
   - Don't include in URLs

### Security Checklist

- [ ] Credentials stored securely (environment variables or encrypted)
- [ ] File permissions set to 600 for encrypted files
- [ ] Validation enabled on startup
- [ ] Log sanitization enabled
- [ ] HTTPS enforced for all requests
- [ ] Domain allowlist configured
- [ ] Rate limiting enabled
- [ ] Monitoring enabled
- [ ] Credentials rotated regularly
- [ ] Backup credentials stored securely

---

## Troubleshooting

### Common Issues

#### "Credential validation failed"

**Cause:** Missing or invalid environment variable

**Solution:**
```bash
# Check if variable is set
echo $PERPLEXITY_API_KEY

# Set variable
export PERPLEXITY_API_KEY="your-key-here"

# Make permanent
echo 'export PERPLEXITY_API_KEY="your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

#### "GPG encryption failed"

**Cause:** GPG not installed or no key pair

**Solution:**
```bash
# Install GPG
brew install gnupg  # macOS
sudo apt-get install gnupg  # Ubuntu

# Generate key pair
gpg --gen-key

# Verify
gpg --list-keys
```

#### "Cannot access OS keychain"

**Cause:** Keychain locked or permission denied

**Solution:**
```bash
# macOS: Unlock keychain
security unlock-keychain

# Linux: Ensure secret service is running
systemctl --user status gnome-keyring

# Windows: Check Credential Manager access
```

#### "Credential found in logs"

**Cause:** Log sanitization not enabled or failed

**Solution:**
```bash
# Sanitize logs immediately
.claude-plugin/hooks/mcp-log-sanitizer.sh sanitize ralph/logs/mcp-usage.log

# Enable automatic sanitization
# Edit .mcp.json:
{
  "security": {
    "sanitize_logs_on_write": true
  }
}

# Watch logs in real-time
.claude-plugin/hooks/mcp-log-sanitizer.sh watch ralph/logs/mcp-usage.log
```

### Security Audit

**Run complete security audit:**

```bash
# 1. Validate credentials
.claude-plugin/hooks/mcp-credential-validator.sh

# 2. Check log files
.claude-plugin/hooks/mcp-log-sanitizer.sh scan ralph/logs/

# 3. Verify file permissions
ls -la .claude-plugin/.ralph-cache/mcp-credentials.enc

# 4. Check configuration
cat .claude-plugin/.mcp.json | jq .security

# 5. Test MCP connection
ralph/scripts/mcp-test-connection.sh
```

---

## Support

**Security Issues:**
- Report security vulnerabilities privately
- Email: security@svrnty.com
- GitHub Security Advisory: https://github.com/snarktank/ralph/security/advisories

**Documentation:**
- MCP Configuration: `.claude-plugin/.mcp.json`
- MCP Usage Guide: `.claude-plugin/MCP-USAGE.md`
- Plugin README: `README.md`

**Tools:**
- Credential Validator: `.claude-plugin/hooks/mcp-credential-validator.sh`
- Credential Manager: `.claude-plugin/hooks/mcp-credential-manager.sh`
- Log Sanitizer: `.claude-plugin/hooks/mcp-log-sanitizer.sh`

---

## Updates

**Last Updated:** 2026-01-11

**Version:** 1.0.0

**Changes:**
- Initial security implementation
- Credential encryption support
- OS keychain integration
- Log sanitization
- Startup validation
- Comprehensive documentation
