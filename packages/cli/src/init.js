import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function init(options) {
  const cwd = process.cwd();
  const ralphDir = path.join(cwd, 'ralph');

  console.log('');
  console.log('\x1b[36m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
  console.log('\x1b[36m║                    RALPH INITIALIZATION                               ║\x1b[0m');
  console.log('\x1b[36m║              Autonomous AI Agent Loop for Claude Code                ║\x1b[0m');
  console.log('\x1b[36m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
  console.log('');

  // Check if ralph directory exists
  if (fs.existsSync(ralphDir) && !options.force) {
    console.log('\x1b[33m⚠ ralph/ directory already exists\x1b[0m');
    console.log('  Use --force to overwrite existing files');
    console.log('  Or run "ralph run" to continue existing loop');
    return;
  }

  // Create ralph directory
  if (!fs.existsSync(ralphDir)) {
    fs.mkdirSync(ralphDir, { recursive: true });
  }

  // Copy templates
  const templatesDir = path.join(__dirname, '..', 'templates');
  const templates = ['prompt.md', 'prd.json.example'];

  for (const template of templates) {
    const src = path.join(templatesDir, template);
    const dest = path.join(ralphDir, template);

    if (fs.existsSync(src)) {
      fs.copyFileSync(src, dest);
      console.log(`\x1b[32m✓ Created ${template}\x1b[0m`);
    }
  }

  // Create progress.txt
  const progressContent = `# Ralph Progress Log
# Project: ${path.basename(cwd)}
# Started: ${new Date().toISOString()}

---

`;
  fs.writeFileSync(path.join(ralphDir, 'progress.txt'), progressContent);
  console.log('\x1b[32m✓ Created progress.txt\x1b[0m');

  // Detect quality gates
  console.log('');
  console.log('\x1b[34m→ Detecting quality gates...\x1b[0m');

  const packageJsonPath = path.join(cwd, 'package.json');
  if (fs.existsSync(packageJsonPath)) {
    const pkg = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    const scripts = pkg.scripts || {};

    if (scripts.typecheck || scripts['type-check']) {
      console.log('  \x1b[32m✓\x1b[0m Typecheck: npm run typecheck');
    }
    if (scripts.test) {
      console.log('  \x1b[32m✓\x1b[0m Tests: npm test');
    }
    if (scripts.lint) {
      console.log('  \x1b[32m✓\x1b[0m Lint: npm run lint');
    }
    if (scripts.build) {
      console.log('  \x1b[32m✓\x1b[0m Build: npm run build');
    }
  } else {
    console.log('  \x1b[33m⚠\x1b[0m No package.json found - configure quality gates manually');
  }

  // Success
  console.log('');
  console.log('\x1b[32m╔══════════════════════════════════════════════════════════════════════╗\x1b[0m');
  console.log('\x1b[32m║                    RALPH INITIALIZED                                  ║\x1b[0m');
  console.log('\x1b[32m╚══════════════════════════════════════════════════════════════════════╝\x1b[0m');
  console.log('');
  console.log('Next steps:');
  console.log('  1. Create your PRD: Copy prd.json.example to prd.json and customize');
  console.log('  2. Review prompt.md and adjust for your project');
  console.log('  3. Run: ralph run');
  console.log('');
  console.log('Or use Claude Code directly:');
  console.log('  ralph install   # Install as /ralph command');
  console.log('  /ralph          # Run from Claude Code');
  console.log('');
}
