# MCP Integration Usage Guide

## Overview

The BMAD Ralph Plugin integrates with the Model Context Protocol (MCP) to provide external service capabilities during loop execution. This enables the Ralph agent to perform research, search for information, and access external data sources while implementing stories.

## Configured MCP Servers

### Perplexity AI Research

**Purpose:** AI-powered search and research capabilities

**Capabilities:**
- Web search with AI-powered synthesis
- Deep research on technical topics
- API and library documentation lookup
- Best practices and implementation patterns

**Configuration Location:** `.claude-plugin/.mcp.json`

## Setup Instructions

### 1. Install Perplexity API Key

The Perplexity MCP server requires an API key from Perplexity AI.

**Get Your API Key:**
1. Sign up at https://www.perplexity.ai/
2. Navigate to API settings
3. Generate a new API key
4. Copy the key for the next step

**Set Environment Variable:**

```bash
# Add to your shell profile (~/.zshrc, ~/.bashrc, etc.)
export PERPLEXITY_API_KEY="your-api-key-here"

# Reload your shell
source ~/.zshrc  # or source ~/.bashrc
```

### 2. Verify MCP Configuration

The plugin automatically loads MCP configuration from `.claude-plugin/.mcp.json`.

**Check Configuration:**
```bash
# View MCP config
cat .claude-plugin/.mcp.json | jq .

# Verify environment variable is set
echo $PERPLEXITY_API_KEY
```

### 3. Test MCP Connection

The MCP server is automatically initialized when the plugin loads. You can verify it's working by checking the logs.

**Check MCP Logs:**
```bash
# View MCP usage logs
tail -f ralph/logs/mcp-usage.log
```

## Usage During Loop Execution

### When MCP is Invoked

The Ralph agent will automatically use MCP capabilities when:

1. **Research Phase:** Investigating unfamiliar libraries, APIs, or patterns
2. **Implementation:** Looking up syntax, best practices, or examples
3. **Troubleshooting:** Searching for error messages or solutions
4. **Validation:** Verifying implementation approaches

### Available MCP Tools

#### perplexity_search

**Purpose:** Quick web search with AI synthesis

**Usage:**
```
Agent invokes: perplexity_search("React hooks best practices 2024")
Returns: Synthesized answer with sources
```

**Best For:**
- Quick lookups
- Current information
- Best practices
- Syntax verification

#### perplexity_research

**Purpose:** Deep research with comprehensive analysis

**Usage:**
```
Agent invokes: perplexity_research("PostgreSQL performance optimization techniques")
Returns: Detailed research report with multiple sources
```

**Best For:**
- Architectural decisions
- Complex topics
- Trade-off analysis
- Implementation strategies

## Configuration Reference

### Server Configuration

Located in `.claude-plugin/.mcp.json`:

```json
{
  "servers": {
    "perplexity": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-perplexity"],
      "capabilities": {
        "search": true,
        "research": true
      }
    }
  }
}
```

### Retry Policy

**Configuration:**
- Max attempts: 3
- Backoff multiplier: 2x
- Max backoff: 30 seconds
- Retry on: timeout, network_error, rate_limit

**Behavior:**
- First attempt fails → wait 2 seconds
- Second attempt fails → wait 4 seconds
- Third attempt fails → give up, continue without MCP

### Rate Limiting

**Configuration:**
- Requests per minute: 10
- Burst size: 5

**Behavior:**
- Normal operation: 10 requests/minute
- Burst support: Up to 5 requests at once
- Rate limit exceeded: Automatic backoff with retry

### Error Handling

**Authentication Failure:**
- Action: Fail fast
- Behavior: Show clear error message, don't retry
- Resolution: Check PERPLEXITY_API_KEY environment variable

**Timeout:**
- Action: Retry with backoff
- Behavior: Retry up to 3 times with exponential backoff
- Timeout: 30 seconds per request

**Rate Limit:**
- Action: Backoff and retry
- Behavior: Wait for rate limit window, then retry
- Max wait: 30 seconds

**Fallback:**
- Behavior: Continue loop execution without MCP
- Impact: Agent continues with built-in knowledge
- Logging: Error logged to ralph/logs/mcp-usage.log

## Security

### Credential Handling

**Best Practices:**
- ✅ Store API keys in environment variables
- ✅ Never commit API keys to version control
- ✅ Use different keys for development/production
- ❌ Never hardcode keys in configuration files
- ❌ Never log API keys

**Environment Variable Pattern:**
```json
"env": {
  "PERPLEXITY_API_KEY": "${PERPLEXITY_API_KEY}"
}
```

### Network Security

**Allowed Domains:**
- api.perplexity.ai
- *.anthropic.com

**Encrypted Transport:**
- All MCP requests use HTTPS
- API keys transmitted securely
- No credential storage at rest

## Monitoring

### Usage Tracking

**Log Location:** `ralph/logs/mcp-usage.log`

**Tracked Metrics:**
- Request count
- Response time
- Error rate
- Cache hit rate

**View Usage:**
```bash
# View recent MCP activity
tail -20 ralph/logs/mcp-usage.log

# Count requests by type
grep "search" ralph/logs/mcp-usage.log | wc -l
grep "research" ralph/logs/mcp-usage.log | wc -l

# Calculate average response time
grep "response_time" ralph/logs/mcp-usage.log | \
  awk '{sum+=$NF; count++} END {print sum/count "ms"}'
```

### Cache Behavior

**Configuration:**
- Cache enabled: true
- TTL: 300 seconds (5 minutes)

**Benefits:**
- Faster responses for repeated queries
- Reduced API usage
- Lower costs

**Cache Hit Rate:**
```bash
# View cache statistics
grep "cache_hit" ralph/logs/mcp-usage.log | tail -10
```

## Troubleshooting

### Common Issues

#### "PERPLEXITY_API_KEY not set"

**Cause:** Environment variable not configured

**Solution:**
```bash
# Set environment variable
export PERPLEXITY_API_KEY="your-key-here"

# Verify it's set
echo $PERPLEXITY_API_KEY

# Make permanent by adding to ~/.zshrc or ~/.bashrc
```

#### "Connection timeout"

**Cause:** Network issues or MCP server not responding

**Solution:**
1. Check internet connection
2. Verify Perplexity API status
3. Increase timeout in .mcp.json
4. Check firewall/proxy settings

#### "Rate limit exceeded"

**Cause:** Too many requests in short time

**Solution:**
1. Wait 60 seconds for rate limit reset
2. Reduce request frequency
3. Upgrade Perplexity API plan (if needed)

#### "Authentication failed"

**Cause:** Invalid or expired API key

**Solution:**
1. Verify API key is correct
2. Check if key is expired
3. Generate new key from Perplexity dashboard
4. Update environment variable

### Debug Mode

**Enable Debug Logging:**
```bash
# Edit .mcp.json
{
  "global_settings": {
    "log_level": "debug"
  }
}
```

**View Debug Logs:**
```bash
# Tail logs with debug output
tail -f ralph/logs/mcp-usage.log

# Filter for errors
grep "ERROR" ralph/logs/mcp-usage.log
```

## Advanced Configuration

### Custom Timeout

**Edit .mcp.json:**
```json
{
  "servers": {
    "perplexity": {
      "timeout_seconds": 60
    }
  }
}
```

### Custom Retry Policy

**Edit .mcp.json:**
```json
{
  "servers": {
    "perplexity": {
      "retry_policy": {
        "max_attempts": 5,
        "backoff_multiplier": 3,
        "max_backoff_seconds": 60
      }
    }
  }
}
```

### Disable Caching

**Edit .mcp.json:**
```json
{
  "global_settings": {
    "cache_responses": false
  }
}
```

## Best Practices

### When to Use MCP

**Good Use Cases:**
- ✅ Researching unfamiliar libraries or frameworks
- ✅ Looking up current best practices
- ✅ Verifying API syntax or signatures
- ✅ Finding solutions to specific error messages

**Avoid Using MCP For:**
- ❌ Information already in codebase
- ❌ Basic programming concepts
- ❌ Project-specific domain knowledge
- ❌ Trivial lookups that waste API quota

### Performance Optimization

**Tips:**
1. Cache responses are reused for 5 minutes
2. Use specific queries for better results
3. Combine related lookups in single research call
4. Monitor usage logs to track API consumption

### Cost Management

**Perplexity API Costs:**
- Free tier: Limited requests/month
- Paid tiers: Based on usage
- Monitor: Track usage in ralph/logs/mcp-usage.log

**Reduce Costs:**
1. Enable caching (default: enabled)
2. Use search vs research appropriately
3. Avoid redundant queries
4. Set reasonable rate limits

## Integration with Ralph Loops

### Automatic Integration

MCP is automatically available during:
- Story implementation
- Quality gate execution
- Error troubleshooting

### Manual Invocation

The agent decides when to use MCP based on:
- Task complexity
- Knowledge requirements
- Available information

### Logging

**MCP Usage Logged To:**
- ralph/logs/mcp-usage.log (usage metrics)
- ralph/loops/*/progress.txt (when MCP helps complete story)

## Future Enhancements

**Planned:**
- Additional MCP servers (web-fetch, filesystem)
- Custom MCP server support
- Enhanced caching strategies
- Usage analytics dashboard

## Support

**Issues:**
- Plugin issues: https://github.com/snarktank/ralph/issues
- Perplexity API: https://docs.perplexity.ai/
- MCP Protocol: https://modelcontextprotocol.io/

**Documentation:**
- Plugin README: ../README.md
- Architecture: ../docs/architecture-bmad-ralph-plugin-2026-01-11.md
- PRD: ../docs/prd-bmad-ralph-plugin-2026-01-11.md
