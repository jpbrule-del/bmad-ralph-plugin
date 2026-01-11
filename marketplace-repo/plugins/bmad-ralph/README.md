# BMAD Ralph Plugin

Autonomous development loop automation using the BMAD Method for executing sprints with quality gates, git workflow, and feedback tracking.

## Overview

BMAD Ralph Plugin transforms your Claude Code into an autonomous development powerhouse. It executes sprint stories in priority order, runs quality gates after each story, handles git workflows automatically, and tracks progress with detailed feedback.

## Features

### 🔄 Autonomous Loop Execution
Execute sprint stories in priority order with automatic iteration. Ralph reads your sprint status, picks the next story, implements it, runs quality gates, and commits automatically.

### ✅ Quality Gate Integration
Run tests, linting, and builds after each story completion. Configurable quality gates ensure code quality before commits are made.

### 🌿 Git Workflow Automation
Automatic branch management, commits, and pull request creation. Ralph handles the entire git workflow so you can focus on planning.

### 📊 Progress Tracking
Detailed progress logs with iteration metrics and feedback. Track loop execution, story completion rates, and quality gate results.

### 🚨 Stuck Detection
Automatic detection and handling of blocked stories. Ralph detects when stories are stuck and provides diagnostic information.

### 🔍 MCP Integration
Perplexity AI research during story implementation. Ralph can research unfamiliar technologies and best practices during execution.

### 🪝 Hook System
Extensible hooks for pre-commit, post-story, and lifecycle events. Customize Ralph's behavior with your own scripts.

### 📈 Feedback Analytics
Aggregate feedback reports with satisfaction metrics. Track loop effectiveness and identify improvement opportunities.

## Installation

### Quick Install via Claude Code

```bash
claude-code plugin install svrnty/bmad-ralph
```

### Manual Installation

```bash
# Clone the plugin repository
git clone https://github.com/svrnty/bmad-ralph-plugin.git

# Install the plugin
cd bmad-ralph-plugin
claude-code plugin install .
```

### Dependencies

Ralph requires the following tools:

- **jq** (>=1.6) - JSON processor
- **yq** (>=4.0) - YAML processor
- **git** (>=2.0) - Version control

Optional:
- **npm** (>=8.0) - For running quality gates

## Quick Start

1. Initialize Ralph in your BMAD project:
```bash
/bmad-ralph:init
```

2. Create a loop for your sprint:
```bash
/bmad-ralph:create my-sprint
```

3. Run the loop:
```bash
/bmad-ralph:run my-sprint
```

4. Monitor progress:
```bash
/bmad-ralph:status my-sprint
```

## Commands

- `/bmad-ralph:init` - Initialize Ralph in BMAD project
- `/bmad-ralph:create <name>` - Create new automation loop
- `/bmad-ralph:run <name>` - Execute automation loop
- `/bmad-ralph:status <name>` - Monitor loop execution
- `/bmad-ralph:list` - See all loops
- `/bmad-ralph:show <name>` - See detailed loop info
- `/bmad-ralph:edit <name>` - Modify loop configuration
- `/bmad-ralph:clone <source> <dest>` - Copy loop configurations
- `/bmad-ralph:delete <name>` - Remove loops
- `/bmad-ralph:archive <name>` - Archive completed loops
- `/bmad-ralph:unarchive <name>` - Restore archived loops
- `/bmad-ralph:config` - Manage Ralph configuration
- `/bmad-ralph:feedback-report` - View feedback analytics

## Documentation

- [Full Documentation](https://github.com/svrnty/bmad-ralph-plugin#readme)
- [Command Reference](https://github.com/svrnty/bmad-ralph-plugin/blob/main/docs/commands.md)
- [Hook System](https://github.com/svrnty/bmad-ralph-plugin/blob/main/docs/hooks.md)
- [MCP Integration](https://github.com/svrnty/bmad-ralph-plugin/blob/main/.claude-plugin/MCP-USAGE.md)

## Use Cases

### For Agile Teams
Automate sprint execution with quality gates and feedback tracking. Let Ralph handle story implementation while you focus on planning and review.

### For Solo Developers
Get a tireless development partner that executes stories while you sleep. Wake up to completed stories with passing tests.

### For Tech Leads
Maintain code quality with automated quality gates. Track team velocity and identify improvement opportunities.

### For Startups
Move fast without breaking things. Ralph ensures quality gates pass before commits, maintaining code quality at speed.

## Support

- **Issues**: [GitHub Issues](https://github.com/svrnty/bmad-ralph-plugin/issues)
- **Discussions**: [GitHub Discussions](https://github.com/svrnty/bmad-ralph-plugin/discussions)
- **Documentation**: [Full Docs](https://github.com/svrnty/bmad-ralph-plugin#readme)

## License

MIT License - see [LICENSE](https://github.com/svrnty/bmad-ralph-plugin/blob/main/LICENSE)

## Author

**Svrnty**
- Website: https://svrnty.com
- GitHub: https://github.com/svrnty
- Email: contact@svrnty.com
