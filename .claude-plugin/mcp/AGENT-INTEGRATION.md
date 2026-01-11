# MCP Integration Guide for Ralph Agents

## Overview

This guide explains how Ralph agents and skills can leverage Model Context Protocol (MCP) capabilities during loop execution. MCP provides external service integration, primarily featuring Perplexity AI for research and search capabilities.

## Available MCP Tools

### Perplexity AI Integration

The Ralph plugin integrates with Perplexity AI through the following MCP tools:

#### 1. `mcp__perplexity__perplexity_search`

**Purpose:** Quick web search with AI-powered synthesis

**When to Use:**
- Looking up current API syntax or function signatures
- Verifying best practices for a specific technology
- Quick fact-checking during implementation
- Finding recent documentation or release notes

**Usage Pattern:**
```
Use the mcp__perplexity__perplexity_search tool with query parameter
Example: "React hooks useEffect cleanup pattern 2024"
Returns: Synthesized answer with sources
```

**Response Time:** Fast (typically < 5 seconds)

**Best For:**
- ✅ Quick lookups and verifications
- ✅ Current information (latest versions, recent releases)
- ✅ Syntax verification
- ✅ Best practices confirmation

#### 2. `mcp__perplexity__perplexity_research`

**Purpose:** Deep research with comprehensive analysis

**When to Use:**
- Making architectural decisions
- Comparing multiple implementation approaches
- Understanding complex technical concepts
- Researching performance optimization strategies
- Investigating security best practices

**Usage Pattern:**
```
Use the mcp__perplexity__perplexity_research tool with messages parameter
Example: Research "PostgreSQL vs MySQL performance characteristics for time-series data"
Returns: Detailed research report with multiple sources and analysis
```

**Response Time:** Slower (typically 10-30 seconds)

**Best For:**
- ✅ Architectural decisions
- ✅ Trade-off analysis
- ✅ Complex topic investigation
- ✅ Implementation strategy research

#### 3. `mcp__perplexity__perplexity_ask`

**Purpose:** Conversational AI assistance

**When to Use:**
- General technical questions
- Clarifying concepts
- Getting explanations of error messages

**Usage Pattern:**
```
Use the mcp__perplexity__perplexity_ask tool with messages parameter
Example: "What causes this error: 'TypeError: Cannot read property of undefined'?"
Returns: Conversational answer with context
```

**Best For:**
- ✅ Technical questions
- ✅ Error explanation
- ✅ Concept clarification

#### 4. `mcp__perplexity__perplexity_reason`

**Purpose:** Reasoning tasks with deep analysis

**When to Use:**
- Complex problem-solving requiring step-by-step reasoning
- Debugging intricate issues
- Planning implementation approaches

**Usage Pattern:**
```
Use the mcp__perplexity__perplexity_reason tool with messages parameter
Example: Reasoning through "Why would a React component re-render infinitely?"
Returns: Step-by-step reasoning with analysis
```

**Best For:**
- ✅ Complex problem-solving
- ✅ Root cause analysis
- ✅ Implementation planning

## When Agents Should Use MCP

### Good Use Cases

**During Story Implementation:**
1. **Unfamiliar Library/Framework**
   - Story requires using a library not previously used in codebase
   - Example: "Implement OAuth using passport.js"
   - Action: Research passport.js integration patterns

2. **Current Best Practices**
   - Need to verify latest recommended approaches
   - Example: "Add form validation with modern React patterns"
   - Action: Search for current React form validation best practices

3. **Error Troubleshooting**
   - Encountering unfamiliar error messages
   - Example: Quality gate fails with cryptic error
   - Action: Research the specific error message

4. **Performance Optimization**
   - Need to optimize slow operations
   - Example: "Improve database query performance"
   - Action: Research PostgreSQL query optimization techniques

5. **Security Implementation**
   - Implementing security features correctly
   - Example: "Add JWT authentication"
   - Action: Research JWT security best practices

6. **API Integration**
   - Integrating with external APIs
   - Example: "Connect to Stripe payment API"
   - Action: Research Stripe API integration patterns

### When NOT to Use MCP

**Avoid MCP For:**

1. **Project-Specific Information**
   - ❌ Information already in codebase
   - ❌ Project conventions and patterns
   - ❌ Domain-specific business logic
   - **Instead:** Use Grep, Read, and Glob tools to explore codebase

2. **Basic Programming Concepts**
   - ❌ Fundamental language syntax
   - ❌ Common patterns already in agent knowledge
   - ❌ Trivial lookups
   - **Instead:** Use built-in knowledge

3. **Already Available Information**
   - ❌ Data in architecture documents
   - ❌ Patterns demonstrated in existing code
   - ❌ Requirements in PRD or story descriptions
   - **Instead:** Read project documentation

4. **Excessive API Usage**
   - ❌ Repeated lookups of the same information
   - ❌ Wasteful queries that don't add value
   - ❌ Using research when search would suffice
   - **Instead:** Remember context from previous queries (responses are cached for 5 minutes)

## Integration Patterns for Ralph Agents

### Pattern 1: Research Before Implementation

```markdown
STORY: Implement rate limiting for API endpoints

AGENT WORKFLOW:
1. Read story from sprint-status.yaml
2. Check codebase for existing rate limiting patterns (Grep)
3. If no existing pattern found → Use MCP to research:
   - Query: "Node.js Express rate limiting best practices 2024"
4. Choose implementation approach based on research
5. Implement story using researched patterns
6. Test implementation
7. Commit with message mentioning MCP usage if it significantly helped
```

### Pattern 2: Troubleshooting Quality Gate Failures

```markdown
SITUATION: Quality gate (tests) failing with error

AGENT WORKFLOW:
1. Run quality gate, capture error output
2. Attempt to understand error using built-in knowledge
3. If error is unfamiliar → Use MCP to investigate:
   - Query: "Jest error: Cannot find module from 'test.js'"
4. Apply solution from research
5. Re-run quality gate
6. Continue if passing, or iterate
```

### Pattern 3: Architectural Decision Making

```markdown
STORY: Add caching layer to improve API performance

AGENT WORKFLOW:
1. Read story requirements
2. Identify need for architectural decision (which caching solution?)
3. Use MCP to research options:
   - Research: "Redis vs Memcached for Node.js API caching - trade-offs and performance"
4. Analyze research results against project requirements
5. Choose solution based on research + project context
6. Document decision in progress.txt
7. Implement chosen solution
```

### Pattern 4: Learning New Technology

```markdown
STORY: Add GraphQL endpoint for user queries

SITUATION: GraphQL not currently used in project

AGENT WORKFLOW:
1. Acknowledge unfamiliarity with GraphQL in this codebase
2. Use MCP to research:
   - Search: "GraphQL Apollo Server Express integration"
   - Research: "GraphQL schema design best practices"
3. Study research results
4. Plan implementation based on learned patterns
5. Implement GraphQL endpoint
6. Note learnings in progress.txt for future stories
```

## MCP Usage Best Practices

### 1. Be Specific in Queries

**Good:**
- ✅ "React useEffect cleanup function best practices for WebSocket connections"
- ✅ "PostgreSQL index optimization for timestamp range queries"
- ✅ "Express.js JWT authentication middleware error handling"

**Bad:**
- ❌ "React hooks" (too broad)
- ❌ "database performance" (too vague)
- ❌ "authentication" (not specific enough)

### 2. Choose the Right Tool

| Need | Tool | Reason |
|------|------|--------|
| Quick syntax check | `perplexity_search` | Fast, direct answer |
| Architectural decision | `perplexity_research` | Deep analysis needed |
| Error explanation | `perplexity_ask` | Conversational format |
| Complex debugging | `perplexity_reason` | Step-by-step reasoning |

### 3. Respect Rate Limits

**Configuration:**
- 10 requests per minute
- Burst size: 5 requests

**Best Practice:**
- Combine related questions into single research query
- Use cached responses (5-minute TTL)
- Don't repeat identical queries
- Space out requests when possible

### 4. Log MCP Usage

**When MCP Significantly Helps:**
- Mention in commit message: "feat: Add rate limiting (researched via MCP)"
- Note in progress.txt: "Learning: Used MCP to research rate limiting patterns"
- Include in story completion notes

**Logging:**
All MCP usage is automatically logged to `ralph/logs/mcp-usage.log`

### 5. Handle MCP Failures Gracefully

**If MCP Unavailable:**
- API key not set → Continue with built-in knowledge
- Network timeout → Retry once, then continue
- Rate limit exceeded → Wait and retry, or continue without

**Agent Behavior:**
- MCP is an enhancement, not a requirement
- Agent should always be able to complete stories without MCP
- MCP failures should never block story completion

## Monitoring MCP Usage

### Health Check

```bash
# Verify MCP is properly configured
.claude-plugin/mcp/mcp-health-check.sh
```

### Usage Statistics

```bash
# View MCP usage stats
.claude-plugin/mcp/mcp-usage-stats.sh

# View recent activity only
.claude-plugin/mcp/mcp-usage-stats.sh --recent

# View errors only
.claude-plugin/mcp/mcp-usage-stats.sh --errors
```

### Connection Test

```bash
# Test MCP connectivity
.claude-plugin/mcp/mcp-test-connection.sh
```

### View Logs

```bash
# Tail MCP usage logs
tail -f ralph/logs/mcp-usage.log

# Count requests
grep "search" ralph/logs/mcp-usage.log | wc -l
grep "research" ralph/logs/mcp-usage.log | wc -l
```

## Skills Integration

### Loop Optimization Skill

The loop-optimization skill can recommend MCP usage when:
- Story stuck due to knowledge gaps
- Unfamiliar technology mentioned in story
- Multiple failed attempts on same story

**Recommendation Pattern:**
```
"Consider using MCP research to investigate [technology/pattern] before next attempt"
```

## Configuration Reference

**Location:** `.claude-plugin/.mcp.json`

**Key Settings:**
- `timeout_seconds`: 30
- `max_attempts`: 3 (retry policy)
- `requests_per_minute`: 10 (rate limiting)
- `cache_ttl_seconds`: 300 (5-minute cache)

**Authentication:**
- Environment variable: `PERPLEXITY_API_KEY`
- Set in shell profile: `export PERPLEXITY_API_KEY="your-key"`

## Example Agent Prompts

### Ralph Execution Agent

**Enhanced Responsibilities with MCP:**

```markdown
### 3. Story Implementation

**With MCP Integration:**

Before implementation, assess knowledge gaps:
- Is this technology/library unfamiliar?
- Are current best practices unclear?
- Would research improve implementation quality?

If yes to any:
- Use mcp__perplexity__perplexity_search for quick lookups
- Use mcp__perplexity__perplexity_research for deep investigation
- Apply researched patterns to implementation
- Document MCP usage in progress.txt if it significantly helped
```

### Loop Monitor Agent

**Enhanced Monitoring with MCP:**

```markdown
### Pattern Recognition

**MCP Usage Patterns:**
- Track MCP invocations per story
- Identify stories that required research
- Flag excessive MCP usage (potential knowledge gaps)
- Recommend MCP usage for stuck stories
```

## Troubleshooting

### "PERPLEXITY_API_KEY not set"

**Solution:**
```bash
export PERPLEXITY_API_KEY="your-api-key-here"
# Add to ~/.zshrc or ~/.bashrc to make permanent
```

### "Rate limit exceeded"

**Solution:**
- Wait 60 seconds for rate limit reset
- Reduce request frequency
- Combine related queries
- Use cached responses

### "Connection timeout"

**Solution:**
- Check internet connection
- Verify Perplexity API status
- Increase timeout in `.mcp.json` if needed

## Best Practices Summary

1. **Use MCP Strategically**
   - For unfamiliar technologies
   - For architectural decisions
   - For troubleshooting complex issues

2. **Don't Over-Rely on MCP**
   - Check codebase first
   - Use built-in knowledge when possible
   - MCP is enhancement, not replacement

3. **Be Efficient**
   - Specific queries get better results
   - Choose right tool (search vs research)
   - Respect rate limits

4. **Document Usage**
   - Note significant MCP usage in commit messages
   - Log learnings in progress.txt
   - Help future iterations benefit from research

5. **Monitor and Optimize**
   - Review usage statistics regularly
   - Identify patterns that benefit from MCP
   - Adjust usage based on effectiveness

## References

- **MCP Configuration:** `.claude-plugin/.mcp.json`
- **User Guide:** `.claude-plugin/MCP-USAGE.md`
- **Health Check:** `.claude-plugin/mcp/mcp-health-check.sh`
- **Usage Stats:** `.claude-plugin/mcp/mcp-usage-stats.sh`
- **Connection Test:** `.claude-plugin/mcp/mcp-test-connection.sh`
- **Logs:** `ralph/logs/mcp-usage.log`

---

**Version:** 1.0.0
**Last Updated:** 2026-01-11
**Part of:** BMAD Ralph Plugin - STORY-030
