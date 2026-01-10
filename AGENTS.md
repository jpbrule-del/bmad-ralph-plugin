# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop for Claude Code. It runs Claude Code CLI repeatedly until all PRD items are complete. Each iteration is a fresh Claude session with clean context.

## Commands

```bash
# Initialize Ralph in a project
npx @ralph/cli init

# Run the autonomous loop
npx @ralph/cli run

# Check status
npx @ralph/cli status

# Run the flowchart dev server
cd apps/flowchart && npm run dev

# Build the flowchart
cd apps/flowchart && npm run build
```

## Monorepo Structure

```
packages/
├── cli/           # @ralph/cli - npm installable CLI
├── core/          # Core bash scripts (ralph.sh, prompt.md)
└── skills/        # Claude Code commands (SKILL.md files)

apps/
└── flowchart/     # Interactive React Flow visualization
```

## Key Files

- `packages/core/ralph.sh` - The bash loop that spawns fresh Claude sessions
- `packages/core/prompt.md` - Instructions given to each Claude iteration
- `packages/cli/` - npm-installable CLI for zero-friction usage
- `apps/flowchart/` - Interactive React Flow diagram explaining how Ralph works

## Flowchart

The `apps/flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

To run locally:
```bash
cd apps/flowchart
npm install
npm run dev
```

## Patterns

- Each iteration spawns a fresh Claude Code session with clean context
- Memory persists via git history, `progress.txt`, and `prd.json`
- Stories should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
- Quality gates must pass before commits are made
