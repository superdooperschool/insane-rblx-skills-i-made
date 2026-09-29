#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFileSync, execSync } from 'node:child_process';

const HERE = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const SERVER = path.join(HERE, 'server.mjs').replace(/\//g, '\\');
const CODEX = path.join(os.homedir(), '.codex', 'config.toml');
const STOCK = 'Roblox_Studio';
const NAME = 'rbx';

const mode = process.argv.includes('--uninstall') ? 'uninstall'
  : process.argv.includes('--check') ? 'check' : 'install';

const out = [];
const say = (icon, msg) => { out.push(icon + '  ' + msg); };

function sh(cmd) {
  try { return { ok: true, text: execSync(cmd, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }) }; }
  catch (e) { return { ok: false, text: (e.stdout || '') + (e.stderr || e.message) }; }
}

function pythonOk() {
  try { execFileSync('python', ['-c', 'import tomllib'], { stdio: 'ignore' }); return true; }
  catch { return false; }
}

function tomlValid(file) {
  if (!pythonOk()) return null;
  try {
    execFileSync('python', ['-c', 'import tomllib,sys;tomllib.load(open(sys.argv[1],"rb"))', file], { stdio: 'pipe' });
    return true;
  } catch { return false; }
}

function claudeState() {
  const r = sh('claude mcp list');
  if (!r.ok && !r.text) return { available: false };
  return {
    available: true,
    hasRbx: new RegExp('^\\s*' + NAME + ':', 'm').test(r.text),
    hasStock: new RegExp('^\\s*' + STOCK + ':', 'm').test(r.text),
    connected: new RegExp('^\\s*' + NAME + ':.*Connected', 'm').test(r.text),
  };
}

function codexLines() {
  if (!fs.existsSync(CODEX)) return null;
  return fs.readFileSync(CODEX, 'utf8').split('\n');
}

function findSection(lines, header) {
  const start = lines.findIndex((l) => l.trim() === header);
  if (start < 0) return null;
  let end = start + 1;
  while (end < lines.length && !lines[end].startsWith('[')) end++;
  return { start, end };
}

function writeCodex(lines) {
  const backup = CODEX + '.bak-' + new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
  fs.copyFileSync(CODEX, backup);
  fs.writeFileSync(CODEX, lines.join('\n'), 'utf8');
  const valid = tomlValid(CODEX);
  if (valid === false) {
    fs.copyFileSync(backup, CODEX);
    throw new Error('the edit produced invalid TOML; config restored from ' + backup);
  }
  return { backup, valid };
}

function codexInstall() {
  const lines = codexLines();
  if (!lines) { say('--', 'Codex: no ~/.codex/config.toml, skipped'); return; }

  const running = sh('tasklist /fi "imagename eq codex.exe" /nh').text.includes('codex.exe');
  if (running) say('!!', 'Codex appears to be RUNNING - it rewrites its own config, so verify after closing it');

  let changed = false;
  const stock = findSection(lines, '[mcp_servers.' + STOCK + ']');
  if (stock) { lines.splice(stock.start, stock.end - stock.start); changed = true; say('->', 'Codex: removed [mcp_servers.' + STOCK + ']'); }

  const block = [
    '[mcp_servers.' + NAME + ']',
    'command = "node"',
    "args = ['" + SERVER + "']",
    'startup_timeout_sec = 60',
    '',
  ];
  const mine = findSection(lines, '[mcp_servers.' + NAME + ']');
  if (mine) {
    const current = lines.slice(mine.start, mine.end).join('\n').trim();
    if (current === block.join('\n').trim()) { say('ok', 'Codex: [mcp_servers.' + NAME + '] already correct'); }
    else { lines.splice(mine.start, mine.end - mine.start, ...block); changed = true; say('->', 'Codex: repaired [mcp_servers.' + NAME + ']'); }
  } else {
    while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();
    lines.push('', ...block);
    changed = true;
    say('->', 'Codex: added [mcp_servers.' + NAME + ']');
  }

  if (!changed) return;
  const r = writeCodex(lines);
  say('ok', 'Codex: written, backup at ' + path.basename(r.backup) +
    (r.valid === true ? ', TOML validated' : ', TOML NOT validated (no python)'));
}

function codexUninstall() {
  const lines = codexLines();
  if (!lines) { say('--', 'Codex: no config.toml, skipped'); return; }
  const mine = findSection(lines, '[mcp_servers.' + NAME + ']');
  if (!mine) { say('--', 'Codex: ' + NAME + ' not present'); return; }
  lines.splice(mine.start, mine.end - mine.start, ...[
    '[mcp_servers.' + STOCK + ']',
    'command = "cmd.exe"',
    'args = ["/c", "cd /d %LOCALAPPDATA%\\\\Roblox && .\\\\mcp.bat"]',
    '',
  ]);
  const r = writeCodex(lines);
  say('ok', 'Codex: restored [mcp_servers.' + STOCK + '], backup at ' + path.basename(r.backup));
}

function claudeInstall() {
  const st = claudeState();
  if (!st.available) { say('--', 'Claude Code: `claude` CLI not on PATH, skipped'); return; }
  for (const scope of ['local', 'user']) {
    if (sh('claude mcp remove ' + STOCK + ' -s ' + scope).ok) say('->', 'Claude Code: removed ' + STOCK + ' (' + scope + ' scope)');
  }
  if (st.hasRbx) { say('ok', 'Claude Code: ' + NAME + ' already registered'); return; }
  const r = sh('claude mcp add ' + NAME + ' -s user -- node "' + SERVER + '"');
  say(r.ok ? 'ok' : '!!', 'Claude Code: ' + (r.ok ? 'registered ' + NAME : 'add failed - ' + r.text.trim().split('\n')[0]));
}

function claudeUninstall() {
  const st = claudeState();
  if (!st.available) { say('--', 'Claude Code: `claude` CLI not on PATH, skipped'); return; }
  if (sh('claude mcp remove ' + NAME + ' -s user').ok) say('->', 'Claude Code: removed ' + NAME);
  const r = sh('claude mcp add ' + STOCK + ' -s user -- cmd.exe /c "cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"');
  say(r.ok ? 'ok' : '!!', 'Claude Code: ' + (r.ok ? 'restored ' + STOCK : 'restore failed'));
}

function check() {
  const st = claudeState();
  if (!st.available) say('--', 'Claude Code: `claude` CLI not on PATH');
  else {
    say(st.hasRbx ? 'ok' : '!!', 'Claude Code: ' + NAME + (st.hasRbx ? (st.connected ? ' registered and connected' : ' registered, NOT connected') : ' NOT registered'));
    if (st.hasStock) say('!!', 'Claude Code: stock ' + STOCK + ' is still registered - run without --check to remove it');
  }
  const lines = codexLines();
  if (!lines) say('--', 'Codex: no ~/.codex/config.toml');
  else {
    const mine = findSection(lines, '[mcp_servers.' + NAME + ']');
    const stock = findSection(lines, '[mcp_servers.' + STOCK + ']');
    say(mine ? 'ok' : '!!', 'Codex: ' + NAME + (mine ? ' present' : ' NOT present'));
    if (stock) say('!!', 'Codex: stock ' + STOCK + ' still present');
    if (mine) {
      const argsLine = lines.slice(mine.start, mine.end).find((l) => l.startsWith('args'));
      if (argsLine && argsLine.includes('"') && argsLine.includes('\\')) {
        say('!!', 'Codex: args uses a double-quoted path - backslashes are read as escapes and BREAK the config');
      }
    }
    const v = tomlValid(CODEX);
    say(v === false ? '!!' : v === true ? 'ok' : '--', 'Codex: config.toml ' + (v === true ? 'parses' : v === false ? 'DOES NOT PARSE' : 'not validated (no python)'));
  }
  if (!fs.existsSync(SERVER)) say('!!', 'server.mjs missing at ' + SERVER);
  else say('ok', 'server.mjs present');
}

try {
  if (mode === 'install') { claudeInstall(); codexInstall(); }
  else if (mode === 'uninstall') { claudeUninstall(); codexUninstall(); }
  check();
} catch (e) {
  say('!!', e.message);
  process.exitCode = 1;
}

console.log('rbx setup - ' + mode + '\n');
console.log(out.join('\n'));
const bad = out.filter((l) => l.startsWith('!!'));
console.log('\n' + (bad.length ? bad.length + ' item(s) need attention.' : 'All good.') +
  (mode === 'install' ? ' Restart Claude Code and Codex to pick up changes.' : ''));
