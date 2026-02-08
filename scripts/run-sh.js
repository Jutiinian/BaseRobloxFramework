#!/usr/bin/env node
/**
 * run-sh.js
 * 
 * Usage:
 *   node run-sh.js path/to/script.sh [args...]
 * 
 * Example:
 *   node run-sh.js scripts/install-packages.sh
 *   node run-sh.js scripts/process-remotes.sh --dry-run
 */

const { spawn } = require("child_process");
const path = require("path");

if (process.argv.length < 3) {
  console.error("Usage: node run-sh.js path/to/script.sh [args...]");
  process.exit(1);
}

// Get the script path and arguments
const scriptPath = path.resolve(process.argv[2]);
const args = process.argv.slice(3);

// Spawn the shell script
const child = spawn("sh", [scriptPath, ...args], {
  stdio: "inherit", // stream output directly to console
  shell: false
});

child.on("exit", (code) => {
  if (code === 0) {
    console.log("✅ Script finished successfully");
  } else {
    console.error(`❌ Script exited with code ${code}`);
  }
  process.exit(code);
});

child.on("error", (err) => {
  console.error("❌ Failed to start script:", err);
  process.exit(1);
});