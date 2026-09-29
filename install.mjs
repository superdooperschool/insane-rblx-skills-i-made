#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const valueOf = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : null; };

const dest = path.resolve(valueOf('--dest') || path.join(os.homedir(), '.claude'));
const skillsSrc = path.join(HERE, 'skills');
const skillsDst = path.join(dest, 'skills');
const claudeMd = path.join(dest, 'CLAUDE.md');
const setup = path.join(skillsDst, 'rbx', 'setup.mjs');
const MARK = '.insane-rblx';
const START = '<!-- insane-rblx:start -->';
const END = '<!-- insane-rblx:end -->';
const stamp = new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
const uninstall = flag('--uninstall');
const skipMcp = flag('--no-mcp');
const windows = process.platform === 'win32';

if (Number(process.versions.node.split('.')[0]) < 18) {
  console.error('Node 18 or newer is required. You have ' + process.versions.node + '.');
  process.exit(1);
}

const say = (icon, msg) => console.log(icon + '  ' + msg);
const names = fs.readdirSync(skillsSrc, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);
const blockRe = new RegExp(START + '[\\s\\S]*?' + END + '\\n?');

function runSetup(extra) {
  if (skipMcp) return say('--', 'MCP step skipped (--no-mcp)');
  if (!windows) return say('--', 'The rbx MCP is Windows-only. Skills and rules were installed, MCP skipped.');
  if (!fs.existsSync(setup)) return say('--', 'rbx setup not found, MCP step skipped');
  const mcpBat = path.join(process.env.LOCALAPPDATA || '', 'Roblox', 'mcp.bat');
  if (!extra.length && !fs.existsSync(mcpBat)) {
    say('!!', 'Roblox Studio MCP not found at ' + mcpBat + '. Update Roblox Studio, then run: node "' + setup + '"');
    return;
  }
  execFileSync(process.execPath, [setup, ...extra], { stdio: 'inherit' });
}

function installSkills() {
  fs.mkdirSync(skillsDst, { recursive: true });
  for (const name of names) {
    const to = path.join(skillsDst, name);
    if (fs.existsSync(to)) {
      if (fs.existsSync(path.join(to, MARK))) {
        fs.rmSync(to, { recursive: true, force: true });
      } else {
        const bak = path.join(dest, 'skills-backup', name + '-' + stamp);
        fs.mkdirSync(path.dirname(bak), { recursive: true });
        fs.renameSync(to, bak);
        say('->', 'existing "' + name + '" moved to ' + bak);
      }
    }
    fs.cpSync(path.join(skillsSrc, name), to, { recursive: true });
    fs.writeFileSync(path.join(to, MARK), 'installed by insane-rblx-skills-i-made\n');
  }
  say('ok', names.length + ' skills installed to ' + skillsDst);
}

function installRules() {
  const block = START + '\n' + fs.readFileSync(path.join(HERE, 'CLAUDE.roblox.md'), 'utf8').trim() + '\n' + END + '\n';
  const current = fs.existsSync(claudeMd) ? fs.readFileSync(claudeMd, 'utf8') : '';
  if (current && !blockRe.test(current)) fs.copyFileSync(claudeMd, claudeMd + '.bak-' + stamp);
  const next = blockRe.test(current)
    ? current.replace(blockRe, () => block)
    : (current.trimEnd() ? current.trimEnd() + '\n\n' : '') + block;
  fs.mkdirSync(dest, { recursive: true });
  fs.writeFileSync(claudeMd, next);
  say('ok', 'Roblox rules written to ' + claudeMd);
}

function removeAll() {
  runSetup(['--uninstall']);
  for (const name of names) {
    const to = path.join(skillsDst, name);
    if (fs.existsSync(path.join(to, MARK))) fs.rmSync(to, { recursive: true, force: true });
  }
  if (fs.existsSync(claudeMd)) {
    const current = fs.readFileSync(claudeMd, 'utf8');
    if (blockRe.test(current)) fs.writeFileSync(claudeMd, current.replace(blockRe, () => '').trimEnd() + '\n');
  }
  say('ok', 'uninstalled (skills you had before are in ' + path.join(dest, 'skills-backup') + ' if any)');
}

if (uninstall) {
  removeAll();
} else {
  installSkills();
  installRules();
  runSetup([]);
  console.log('\nNext: restart Claude Code, open Roblox Studio with a place, then ask Claude: run rbx health');
}
