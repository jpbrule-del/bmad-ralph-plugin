import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function install() {
  const homeDir = process.env.HOME || process.env.USERPROFILE;
  const claudeCommandsDir = path.join(homeDir, '.claude', 'commands');

  console.log('');
  console.log('\x1b[36m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
  console.log('\x1b[36m║                    RALPH INSTALLATION                                 ║\x1b[0m');
  console.log('\x1b[36m║              Installing as Claude Code Command                       ║\x1b[0m');
  console.log('\x1b[36m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
  console.log('');

  // Create Claude commands directory if needed
  if (!fs.existsSync(claudeCommandsDir)) {
    fs.mkdirSync(claudeCommandsDir, { recursive: true });
    console.log(`\x1b[32m✓ Created ${claudeCommandsDir}\x1b[0m`);
  }

  // Create the ralph.md command file
  const ralphCommand = `---
description: 'Autonomous AI agent loop - implements stories from your PRD'
---

# Ralph - Autonomous Execution

You are Ralph, an autonomous AI agent loop for Claude Code.

## Purpose

Ralph runs Claude Code repeatedly until all PRD items are complete. Each iteration:
1. Picks the highest priority story where \`passes: false\`
2. Implements that single story
3. Runs quality gates (typecheck, tests)
4. Commits if gates pass
5. Updates prd.json and progress.txt
6. Repeats until all stories pass

## Prerequisites

Ensure you have:
- \`ralph/prd.json\` with your stories
- \`ralph/prompt.md\` with iteration context
- Quality gate commands configured

## Quick Start

If ralph/ doesn't exist, run \`npx @ralph/cli init\` first.

## Your Task

1. Read ralph/prd.json to find the next story
2. Read ralph/progress.txt for context from previous iterations
3. Implement the story
4. Run quality gates
5. If all pass, commit and update prd.json
6. Append learnings to progress.txt

## Signals

- If all stories done: output \`<complete>ALL_STORIES_PASSED</complete>\`
- If stuck: output \`<stuck>STORY_ID: reason</stuck>\`

## Documentation

Full docs: https://github.com/snarktank/ralph
`;

  const commandPath = path.join(claudeCommandsDir, 'ralph.md');
  fs.writeFileSync(commandPath, ralphCommand);
  console.log(`\x1b[32m✓ Installed /ralph command\x1b[0m`);

  // Success
  console.log('');
  console.log('\x1b[32m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
  console.log('\x1b[32m║                    INSTALLATION COMPLETE                              ║\x1b[0m');
  console.log('\x1b[32m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
  console.log('');
  console.log('You can now use Ralph in Claude Code:');
  console.log('  /ralph');
  console.log('');
  console.log('Installation location:');
  console.log(`  ${commandPath}`);
  console.log('');
}
