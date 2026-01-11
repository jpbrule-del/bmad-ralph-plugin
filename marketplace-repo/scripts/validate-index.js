#!/usr/bin/env node

/**
 * Validate marketplace-index.json consistency
 * Ensures all plugins in index have corresponding metadata files
 */

const fs = require('fs');
const path = require('path');

console.log('🔍 Validating marketplace index...\n');

// Read marketplace index
const indexPath = path.join(__dirname, '..', 'marketplace-index.json');
const index = JSON.parse(fs.readFileSync(indexPath, 'utf8'));

let errors = 0;
let warnings = 0;

// Validate each plugin entry
index.plugins.forEach((plugin, idx) => {
  console.log(`Checking plugin ${idx + 1}/${index.plugins.length}: ${plugin.name}`);

  // Check metadata file exists
  const metadataPath = path.join(__dirname, '..', plugin.marketplace_entry);
  if (!fs.existsSync(metadataPath)) {
    console.error(`  ❌ ERROR: metadata.json not found at ${plugin.marketplace_entry}`);
    errors++;
  } else {
    console.log(`  ✅ metadata.json found`);

    // Validate metadata consistency
    const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));

    if (metadata.id !== plugin.id) {
      console.error(`  ❌ ERROR: ID mismatch (index: ${plugin.id}, metadata: ${metadata.id})`);
      errors++;
    }

    if (metadata.version !== plugin.version) {
      console.warn(`  ⚠️  WARNING: Version mismatch (index: ${plugin.version}, metadata: ${metadata.version})`);
      warnings++;
    }

    if (metadata.name !== plugin.name) {
      console.warn(`  ⚠️  WARNING: Name mismatch (index: ${plugin.name}, metadata: ${metadata.name})`);
      warnings++;
    }
  }

  // Check README exists
  const pluginDir = path.dirname(path.join(__dirname, '..', plugin.marketplace_entry));
  const readmePath = path.join(pluginDir, 'README.md');
  if (!fs.existsSync(readmePath)) {
    console.error(`  ❌ ERROR: README.md not found in ${path.basename(pluginDir)}/`);
    errors++;
  } else {
    console.log(`  ✅ README.md found`);
  }

  // Check CHANGELOG exists
  const changelogPath = path.join(pluginDir, 'CHANGELOG.md');
  if (!fs.existsSync(changelogPath)) {
    console.error(`  ❌ ERROR: CHANGELOG.md not found in ${path.basename(pluginDir)}/`);
    errors++;
  } else {
    console.log(`  ✅ CHANGELOG.md found`);
  }

  console.log('');
});

// Summary
console.log('─'.repeat(60));
console.log(`\n📊 Validation Summary:`);
console.log(`   Total plugins: ${index.plugins.length}`);
console.log(`   Errors: ${errors}`);
console.log(`   Warnings: ${warnings}`);

if (errors > 0) {
  console.log('\n❌ Validation failed with errors');
  process.exit(1);
} else if (warnings > 0) {
  console.log('\n⚠️  Validation passed with warnings');
  process.exit(0);
} else {
  console.log('\n✅ Validation passed');
  process.exit(0);
}
