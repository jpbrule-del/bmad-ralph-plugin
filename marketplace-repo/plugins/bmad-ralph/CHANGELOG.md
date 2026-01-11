# Changelog

All notable changes to the BMAD Ralph Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-11

### Added

#### EPIC-001: Plugin Foundation
- Valid plugin.json manifest for Claude Code integration
- Plugin directory structure (commands/, skills/, agents/, hooks/)
- Plugin dependency system with verification (jq, yq, git)
- Plugin configuration system with defaults and project-level overrides
- Plugin permissions system with explicit declarations

#### EPIC-002: Command Migration
- `/bmad-ralph:init` - Initialize Ralph in BMAD projects
- `/bmad-ralph:create` - Create new automation loops
- `/bmad-ralph:run` - Execute automation loops
- `/bmad-ralph:status` - Monitor loop execution with live dashboard
- `/bmad-ralph:list` - List all loops with filtering
- `/bmad-ralph:show` - Display detailed loop information
- `/bmad-ralph:edit` - Modify loop configuration
- `/bmad-ralph:clone` - Copy loop configurations
- `/bmad-ralph:delete` - Remove loops safely
- `/bmad-ralph:archive` - Archive completed loops with feedback
- `/bmad-ralph:unarchive` - Restore archived loops
- `/bmad-ralph:config` - Manage Ralph configuration
- `/bmad-ralph:feedback-report` - View aggregate feedback analytics

#### EPIC-003: Skills & Agents
- Loop Optimization Skill - Auto-invoked performance suggestions
- Ralph Execution Agent - Specialized story execution agent
- Loop Monitor Agent - Intelligent status updates and anomaly detection
- Skill auto-invocation system with context detection

#### EPIC-004: Hooks System
- Comprehensive hooks.json configuration
- Pre-commit hook with quality gate validation
- Post-story hook for completion actions
- Loop lifecycle hooks (start, pause, resume, complete)
- Stuck detection hook with diagnostic information
- Hook execution engine with timeout and failure handling

#### EPIC-005: MCP Integration
- MCP configuration for external service integration
- Perplexity MCP server for AI research during loops
- MCP security with credential validation and encryption
- Helper scripts for health checks and usage analytics

#### EPIC-006: Marketplace & Distribution
- Marketplace manifest for plugin listing
- Installation instructions and screenshots
- Feature descriptions and compatibility information

### Features

- 🔄 Autonomous loop execution with story prioritization
- ✅ Quality gate integration (test, lint, build)
- 🌿 Git workflow automation (branches, commits, PRs)
- 📊 Progress tracking with detailed metrics
- 🚨 Stuck detection with threshold configuration
- 🔍 MCP integration for Perplexity AI research
- 🪝 Extensible hook system for lifecycle events
- 📈 Feedback analytics with satisfaction metrics

### Documentation

- Comprehensive README with quick start guide
- Command reference documentation
- Hook system guide
- MCP usage documentation
- Security best practices

### Quality

- All quality gates passing (lint, build)
- Comprehensive test coverage
- Security review completed
- Dependency verification system
- Error handling and logging

## [Unreleased]

### Planned

- Auto-update support from marketplace
- Version management with changelog generation
- Installation validation and repair
- Additional MCP server integrations
- Enhanced feedback analytics
- Performance optimizations

---

For full release notes and migration guides, see the [GitHub Releases](https://github.com/svrnty/bmad-ralph-plugin/releases) page.
