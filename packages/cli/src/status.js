import fs from 'fs';
import path from 'path';

export async function status() {
  const cwd = process.cwd();
  const ralphDir = path.join(cwd, 'ralph');
  const prdPath = path.join(ralphDir, 'prd.json');
  const progressPath = path.join(ralphDir, 'progress.txt');

  console.log('');
  console.log('\x1b[36m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
  console.log('\x1b[36m║                      RALPH STATUS                                     ║\x1b[0m');
  console.log('\x1b[36m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
  console.log('');

  // Check if initialized
  if (!fs.existsSync(ralphDir)) {
    console.log('\x1b[33m⚠ Ralph not initialized\x1b[0m');
    console.log('  Run "ralph init" to get started');
    return;
  }

  // Check for prd.json
  if (!fs.existsSync(prdPath)) {
    console.log('\x1b[33m⚠ No prd.json found\x1b[0m');
    console.log('  Copy prd.json.example to prd.json and configure your stories');
    return;
  }

  // Load and display status
  const prd = JSON.parse(fs.readFileSync(prdPath, 'utf8'));
  const stories = prd.userStories || [];
  const completed = stories.filter(s => s.passes);
  const pending = stories.filter(s => !s.passes);

  console.log(`\x1b[34mProject:\x1b[0m     ${prd.project || 'Unknown'}`);
  console.log(`\x1b[34mBranch:\x1b[0m      ${prd.branchName || 'N/A'}`);
  console.log('');

  // Progress bar
  const total = stories.length;
  const done = completed.length;
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  const barWidth = 40;
  const filled = Math.round((done / total) * barWidth) || 0;
  const empty = barWidth - filled;

  console.log(`\x1b[34mProgress:\x1b[0m    [${'█'.repeat(filled)}${'░'.repeat(empty)}] ${done}/${total} (${pct}%)`);
  console.log('');

  // Stats
  if (prd.stats) {
    console.log(`\x1b[34mIterations:\x1b[0m  ${prd.stats.iterationsRun || 0}`);
    if (prd.stats.startedAt) {
      console.log(`\x1b[34mStarted:\x1b[0m     ${prd.stats.startedAt}`);
    }
    if (prd.stats.completedAt) {
      console.log(`\x1b[34mCompleted:\x1b[0m   ${prd.stats.completedAt}`);
    }
  }

  // Config
  if (prd.config) {
    console.log('');
    console.log('\x1b[34mConfiguration:\x1b[0m');
    console.log(`  Max iterations: ${prd.config.maxIterations || 50}`);
    console.log(`  Stuck threshold: ${prd.config.stuckThreshold || 3}`);
    if (prd.config.qualityGates) {
      const gates = prd.config.qualityGates;
      if (gates.typecheck) console.log(`  Typecheck: ${gates.typecheck}`);
      if (gates.test) console.log(`  Test: ${gates.test}`);
      if (gates.lint) console.log(`  Lint: ${gates.lint}`);
      if (gates.build) console.log(`  Build: ${gates.build}`);
    }
  }

  // Pending stories
  if (pending.length > 0) {
    console.log('');
    console.log('\x1b[34mPending Stories:\x1b[0m');
    const toShow = pending.slice(0, 5);
    for (const story of toShow) {
      const attempts = story.attempts || 0;
      const attemptStr = attempts > 0 ? ` \x1b[33m(${attempts} attempts)\x1b[0m` : '';
      console.log(`  ${story.id}: ${story.title}${attemptStr}`);
    }
    if (pending.length > 5) {
      console.log(`  ... and ${pending.length - 5} more`);
    }
  }

  // Recent progress
  if (fs.existsSync(progressPath)) {
    const progress = fs.readFileSync(progressPath, 'utf8');
    const lines = progress.split('\n').filter(l => l.startsWith('## Iteration'));
    if (lines.length > 0) {
      console.log('');
      console.log('\x1b[34mRecent Iterations:\x1b[0m');
      const recent = lines.slice(-3);
      for (const line of recent) {
        console.log(`  ${line.replace('## ', '')}`);
      }
    }
  }

  console.log('');
}
