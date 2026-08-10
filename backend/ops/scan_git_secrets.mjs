#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { execFileSync } from 'node:child_process';

import { detectHighConfidenceSecretRules } from './secret_scan_rules.mjs';

const repoRoot = execFileSync('git', ['rev-parse', '--show-toplevel'], {
  encoding: 'utf8',
}).trim();
const findings = new Set();
const workingTreeOnly = process.argv.includes('--working-tree-only');

function inspect(text, source, file) {
  for (const rule of detectHighConfidenceSecretRules(text, file)) {
    findings.add(`${rule}\t${source}\t${file}`);
  }
}

async function scanHistory() {
  const child = spawn('git', [
    'log', '--all', '--full-history', '--no-color', '--no-ext-diff',
    '--format=@@SIT_COMMIT %H', '-p', '--', '.',
  ], { cwd: repoRoot, stdio: ['ignore', 'pipe', 'inherit'] });

  let commit = 'unknown';
  let file = 'unknown';
  let pending = '';
  child.stdout.setEncoding('utf8');
  for await (const chunk of child.stdout) {
    const lines = `${pending}${chunk}`.split('\n');
    pending = lines.pop() ?? '';
    for (const line of lines) {
      if (line.startsWith('@@SIT_COMMIT ')) {
        commit = line.slice('@@SIT_COMMIT '.length).trim();
      } else if (line.startsWith('+++ b/')) {
        file = line.slice(6);
      } else if (line.startsWith('+') && !line.startsWith('+++')) {
        inspect(line.slice(1), commit, file);
      }
    }
  }
  if (pending.startsWith('+') && !pending.startsWith('+++')) {
    inspect(pending.slice(1), commit, file);
  }
  const exitCode = await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', resolve);
  });
  if (exitCode !== 0) throw new Error(`git log failed with exit code ${exitCode}`);
}

async function scanWorkingTree() {
  const tracked = execFileSync(
    'git',
    ['ls-files', '--cached', '--others', '--exclude-standard', '-z'],
    { cwd: repoRoot },
  ).toString('utf8').split('\0').filter(Boolean);

  for (const relativePath of tracked) {
    const absolutePath = path.join(repoRoot, relativePath);
    let stat;
    try {
      stat = await fs.stat(absolutePath);
    } catch {
      continue;
    }
    if (!stat.isFile() || stat.size > 5 * 1024 * 1024) continue;
    const contents = await fs.readFile(absolutePath);
    if (contents.includes(0)) continue;
    inspect(contents.toString('utf8'), 'working-tree', relativePath);
  }
}

if (!workingTreeOnly) await scanHistory();
await scanWorkingTree();

if (findings.size > 0) {
  console.error(`[secret-scan] ${findings.size} high-confidence finding(s)`);
  for (const finding of [...findings].sort()) {
    const [rule, source, file] = finding.split('\t');
    console.error(`[secret-scan] rule=${rule} source=${source} file=${file}`);
  }
  process.exitCode = 1;
} else {
  console.log(workingTreeOnly
    ? '[secret-scan] no high-confidence secrets found in the working tree'
    : '[secret-scan] no high-confidence secrets found in Git history or working tree');
}
