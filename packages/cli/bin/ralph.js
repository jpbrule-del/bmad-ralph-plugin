#!/usr/bin/env node

import { program } from 'commander';
import { init } from '../src/init.js';
import { run } from '../src/run.js';
import { install } from '../src/install.js';
import { status } from '../src/status.js';

program
  .name('ralph')
  .description('Autonomous AI agent loop for Claude Code')
  .version('1.0.0');

program
  .command('init')
  .description('Initialize Ralph in your project')
  .option('-f, --force', 'Overwrite existing files')
  .action(init);

program
  .command('run')
  .description('Run the autonomous loop')
  .option('-m, --max <iterations>', 'Maximum iterations', '50')
  .action(run);

program
  .command('install')
  .description('Install Ralph as a Claude Code command')
  .action(install);

program
  .command('status')
  .description('Show current progress')
  .action(status);

program.parse();
