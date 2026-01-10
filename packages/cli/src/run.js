import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';

export async function run(options) {
  const cwd = process.cwd();
  const ralphDir = path.join(cwd, 'ralph');
  const prdPath = path.join(ralphDir, 'prd.json');
  const promptPath = path.join(ralphDir, 'prompt.md');

  console.log('');
  console.log('\x1b[36m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
  console.log('\x1b[36m║                      RALPH EXECUTION                                  ║\x1b[0m');
  console.log('\x1b[36m║              Autonomous AI Agent Loop for Claude Code                ║\x1b[0m');
  console.log('\x1b[36m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
  console.log('');

  // Check prerequisites
  if (!fs.existsSync(ralphDir)) {
    console.log('\x1b[31m✗ ralph/ directory not found\x1b[0m');
    console.log('  Run "ralph init" first to initialize your project');
    process.exit(1);
  }

  if (!fs.existsSync(prdPath)) {
    console.log('\x1b[31m✗ ralph/prd.json not found\x1b[0m');
    console.log('  Copy prd.json.example to prd.json and configure your stories');
    process.exit(1);
  }

  if (!fs.existsSync(promptPath)) {
    console.log('\x1b[31m✗ ralph/prompt.md not found\x1b[0m');
    console.log('  Run "ralph init" to create the prompt template');
    process.exit(1);
  }

  // Check for claude CLI
  try {
    const which = spawn('which', ['claude']);
    await new Promise((resolve, reject) => {
      which.on('close', (code) => {
        if (code !== 0) reject(new Error('claude not found'));
        else resolve();
      });
    });
  } catch {
    console.log('\x1b[31m✗ Claude Code CLI not found\x1b[0m');
    console.log('  Install with: npm install -g @anthropic-ai/claude-code');
    process.exit(1);
  }

  // Load PRD
  const prd = JSON.parse(fs.readFileSync(prdPath, 'utf8'));
  const stories = prd.userStories || [];
  const pending = stories.filter(s => !s.passes);
  const completed = stories.filter(s => s.passes);

  console.log(`\x1b[34m→ Project:\x1b[0m ${prd.project || 'Unknown'}`);
  console.log(`\x1b[34m→ Stories:\x1b[0m ${completed.length}/${stories.length} complete`);
  console.log(`\x1b[34m→ Max iterations:\x1b[0m ${options.max}`);
  console.log('');

  if (pending.length === 0) {
    console.log('\x1b[32m✓ All stories complete!\x1b[0m');
    process.exit(0);
  }

  // Start the loop
  console.log('\x1b[34m→ Starting autonomous loop...\x1b[0m');
  console.log('  Press Ctrl+C to stop');
  console.log('');

  const maxIterations = parseInt(options.max, 10);

  for (let i = 1; i <= maxIterations; i++) {
    // Re-read PRD to get latest state
    const currentPrd = JSON.parse(fs.readFileSync(prdPath, 'utf8'));
    const currentPending = currentPrd.userStories.filter(s => !s.passes);

    if (currentPending.length === 0) {
      console.log('');
      console.log('\x1b[32m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
      console.log('\x1b[32m║                      RALPH COMPLETE                                   ║\x1b[0m');
      console.log('\x1b[32m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
      process.exit(0);
    }

    const nextStory = currentPending.sort((a, b) => a.priority - b.priority)[0];

    console.log(`\x1b[36m═══════════════════════════════════════════════════════════════════════\x1b[0m`);
    console.log(`\x1b[36m  Iteration ${i}/${maxIterations}: ${nextStory.id}\x1b[0m`);
    console.log(`\x1b[36m═══════════════════════════════════════════════════════════════════════\x1b[0m`);
    console.log(`  ${nextStory.title}`);
    console.log('');

    // Read prompt
    const prompt = fs.readFileSync(promptPath, 'utf8');

    // Run Claude
    const claude = spawn('claude', ['--print', '--dangerously-skip-permissions', '-p', prompt], {
      cwd,
      stdio: ['inherit', 'pipe', 'pipe']
    });

    let output = '';

    claude.stdout.on('data', (data) => {
      output += data.toString();
      process.stdout.write(data);
    });

    claude.stderr.on('data', (data) => {
      process.stderr.write(data);
    });

    await new Promise((resolve) => {
      claude.on('close', resolve);
    });

    // Check for completion signal
    if (output.includes('<complete>ALL_STORIES_PASSED</complete>')) {
      console.log('');
      console.log('\x1b[32m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
      console.log('\x1b[32m║                      RALPH COMPLETE                                   ║\x1b[0m');
      console.log('\x1b[32m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
      process.exit(0);
    }

    // Brief pause between iterations
    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  console.log('');
  console.log('\x1b[33m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
  console.log('\x1b[33m║                  MAX ITERATIONS REACHED                               ║\x1b[0m');
  console.log('\x1b[33m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
  console.log('');
  console.log('Run "ralph run" again to continue');
  process.exit(2);
}
