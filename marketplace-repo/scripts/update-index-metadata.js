#!/usr/bin/env node

/**
 * Update marketplace-index.json metadata with current stats
 * Runs during publish workflow to keep metadata fresh
 */

const fs = require('fs');
const path = require('path');

console.log('📝 Updating marketplace index metadata...\n');

// Read marketplace index
const indexPath = path.join(__dirname, '..', 'marketplace-index.json');
const index = JSON.parse(fs.readFileSync(indexPath, 'utf8'));

// Calculate stats
const totalPlugins = index.plugins.length;
const totalDownloads = index.plugins.reduce((sum, p) => sum + (p.downloads || 0), 0);
const lastUpdated = new Date().toISOString();

// Update metadata
index.metadata = {
  total_plugins: totalPlugins,
  total_downloads: totalDownloads,
  last_updated: lastUpdated,
  index_version: index.version
};

index.updated_at = lastUpdated;

// Write updated index
fs.writeFileSync(indexPath, JSON.stringify(index, null, 2) + '\n', 'utf8');

console.log('✅ Metadata updated:');
console.log(`   Total plugins: ${totalPlugins}`);
console.log(`   Total downloads: ${totalDownloads}`);
console.log(`   Last updated: ${lastUpdated}`);
console.log(`   Index version: ${index.version}`);
